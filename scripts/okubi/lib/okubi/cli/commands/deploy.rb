module Okubi
  module CLI
    module Commands
      class Deploy < Base

        option '--environment', "ENVIRONMENT", "The environment to deploy against", :required => :true

        def execute
          put_command "Deploying FOLIO"

          load_configuration(environment)
          configure_kubernetes

          # Ingress / DNS stuff
          public_address = deploy_ingress_controller
          configure_dnsimple(public_address)
          deploy_okapi
          deploy_ingress
          deploy_lego
          enable_ingress_tls

          create_tenant

          # # TODO: find a better way
          pull_registry

          # Modules are monged into a uniform data structure
          modules = prepare_modules

          # Note: This will only register modules configured with the
          # `module_descriptor` property.  Other modules should have been
          # pulled from the central registry by now.
          register_modules(modules)

          # Resolve module dependencies to compatible versions
          modules = resolve_module_dependencies(modules)

          # Deploy modules to Kubernetes cluster
          deploy_modules(modules)
          discover_modules(modules)
          enable_modules_for_tenant(modules, configatron.tenant)
          create_admin_user

          put_success "FOLIO Successfully Deployed"
          shell_out.run!("kubectl get all")
          exit 0
        end

        def configure_kubernetes
          put_task "Configuring Kubernetes"
          put_info "Setting Context: #{ pastel.yellow(configatron.context) }"

          shell.run!("kubectl config use-context #{configatron.context}")

          put_info "Killing Running 'kubectl' Processes"
          shell.run!('sudo killall -9 kubectl &> /dev/null')

          # TODO: check if one is already running and kill it first
          put_info "Starting Kubernetes Proxy"
          fork do
            exec 'kubectl proxy &> /dev/null'
          end
          sleep 2

          put_info "Connecting To Kubernetes"
          kube_client.discover
        end

        def register_modules(modules)
          modules.select { |folio_module| folio_module.module_descriptor }.each do |folio_module|
            begin
              put_info "Registering #{folio_module.name} With Configured Module Descriptor"
              okapi.post '/_/proxy/modules', MultiJson.load(open(folio_module.module_descriptor).read)
            rescue
              put_warning "Module Descriptor Configured for #{folio_module.name} Is Invalid"
            end
          end
        end

        def deploy_ingress_controller
          put_task "Deploying NGINX Ingress Controller"

          put_info "Create 'nginx-ingress' Namespace"
          shell.run!("kubectl apply -f #{project_root}/kubernetes/ingress/nginx/00-nginx-namespace.yaml")
          sleep 2

          put_info "Deploying Default HTTP Backend"
          shell.run!("kubectl apply -f #{project_root}/kubernetes/ingress/nginx/default-http-backend.yaml")
          sleep 5

          put_info "Deploying NGINX"
          shell.run!("kubectl apply -f #{project_root}/kubernetes/ingress/nginx/nginx-ingress-controller.yaml")
          sleep 5

          put_info "Waiting For Public Address"

          nginx = nil
          with_retries(:limit => 25, :sleep => 5) do
            nginx = kube_client.get_service 'nginx-ingress-controller', 'nginx-ingress'
          end

          until (public_address = nginx&.status&.loadBalancer&.ingress&.first&.ip)
            sleep 10
            nginx = kube_client.get_service 'nginx-ingress-controller', 'nginx-ingress'
          end

          put_info "Public Address: #{public_address}"
          return public_address
        end

        def configure_dnsimple(public_address)
          put_task "Configuring DNSimple"

          # Gather info required for DNSimple API
          uri = URI(configatron.host)
          record_name = uri.host.split('.')[0]
          zone_name = uri.host.split('.')[1..-1].join('.')

          account_id = dnsimple_client.identity.whoami.data.account.id
          record_id = dnsimple_client.zones.all_records(
            account_id,
            zone_name
          ).data.find { |record| record.name == record_name }.id


          put_info "Updating Record '#{uri.host}' -> #{public_address}"
          dnsimple_client.zones.update_record(
            account_id,
            'frontside.io',
            record_id,
            content: "#{public_address}"
          )

          put_info "Waiting for DNS refresh"
          until Resolv.getaddress(uri.host) == "#{public_address}"
            sleep 5
          end
        end

        def deploy_lego
          put_task "Deploying 'kube-lego' Certificate Manager"

          put_info "Create 'kube-lego' Namespace"
          shell.run!("kubectl apply -f #{project_root}/kubernetes/ingress/lego/00-lego-namespace.yaml")

          put_info "Configuring Lego"
          shell.run!("kubectl apply -f #{project_root}/kubernetes/ingress/lego/lego-configmap.yaml")

          put_info "Deploying Lego"
          shell.run!("kubectl apply -f #{project_root}/kubernetes/ingress/lego/lego.yaml")
        end

        def deploy_ingress
          put_task "Deploying Ingress"

          apply_from_template(
            "#{project_root}/kubernetes/ingress/ingress.tmpl.yaml",
            'ingress',
            host: URI(configatron.host).host
          )
        end

        def enable_ingress_tls
          put_task "Enabling TLS Termination (HTTPS)"

          apply_from_template(
            "#{project_root}/kubernetes/ingress/ingress-tls.tmpl.yaml",
            'ingress-tls',
            host: URI(configatron.host).host
          )

          put_info "Verifying Certificate for #{configatron.host}"
          until SSLTest.test(configatron.host)[0]
            sleep 3
          end
        end

        def deploy_okapi
          put_task "Deploying Okapi"

          put_info "Applying Kubernetes Manifest"

          # To be revisited. The Okapi Dockerfile doesn't include an entrypoint,
          # nor does it seem to work out of the box.  Generally when Okapi
          # is started it requires a command and takes options, but that
          # never seems to happen and the logs show Okapi carping about the
          # lack of command.  We may have to go back to building our own Okapi
          # images with augmented Dockerfiles.

          apply_from_template(
            "#{project_root}/kubernetes/okapi/okapi.tmpl.yaml",
            'okapi',
            okapi: configatron.okapi,
            storage: configatron.storage
          )

          sleep 10

          # Wait until Okapi is "Ready" before proceeding
          put_info "Waiting for Okapi Pod to Achieve #{ pastel.yellow('Ready') } State"
          okapi_pod = kube_client.get_pods(label_selector: 'run=okapi').first
          until okapi_pod && okapi_pod.status.containerStatuses.map(&:ready).all? do
            okapi_pod = kube_client.get_pods(label_selector: 'run=okapi').first
            sleep 10
          end
        end

        def prepare_modules
          # This builds a more palatable data structure from our
          # parsed config file.  At some point 'module_config' may warrant
          # a full-blown module, but for now a Struct seems to get the job done
          modules = configatron.modules.map { |module_config| module_config.to_hashugar }
          modules.map! do |module_config|
            installation_payload = module_config.tag ?
               { id: "#{module_config.name}-#{module_config.tag}", action: 'enable' } :
                                     { id: module_config.name, action: 'enable' }

            Hashugar.new(
              name: module_config.name,
              tag: module_config.tag,
              manifest: module_config.manifest,
              image: module_config.image,
              rolling: module_config.rolling,
              priority: module_config.priority,
              env: Array(module_config.env), # don't choke on `.each`
              hold: module_config.hold,
              module_descriptor: module_config.module_descriptor,
              installation_payload: installation_payload
            )
          end

          # Sort any module with a priority to the top, and sort those
          # in ascending order.
          modules.sort_by! { |child| [child.priority ? 0 : 1,child.priority || 0] }

          return modules
        end

        def deploy_module(folio_module)
          # Inject appropriate values into a Kubernetes manifest template
          # according to what was found in `folio.conf`, then apply
          # the manifests to the cluster.  If the corresponding resoures
          # already exist, any change should trigger a RollingUpdate
          apply_from_template(
            "#{project_root}/kubernetes/folio_modules/folio-module.tmpl.yaml",
            folio_module.name,
            folio_module: folio_module,
            storage: configatron.storage
          )

          if folio_module.priority
            put_bullet "#{pastel.bold.yellow('(PRIORITY)')} #{folio_module.name}"
            blocking_pod = kube_client.get_pods(label_selector: "run=#{folio_module.name}").first
            until blocking_pod && blocking_pod&.status&.containerStatuses&.map(&:ready)&.all? do
              sleep 10
              blocking_pod = kube_client.get_pods(label_selector: "run=#{folio_module.name}").first
            end
          else
            put_bullet "#{folio_module.name}"
          end
        end

        def deploy_modules(modules)
          put_task "Deploying FOLIO Modules"

          modules.each do |folio_module|
            deploy_module(folio_module)
          end

          # Here we use the kubeclient gem to monitor the status of the Pods
          # that were erected by the Deployments we just applied.  Pods contain
          # multiple containers, and must be completely ready and healthy before
          # we proceed with discovery.
          put_info "Waiting for Module Pods to Achieve #{ pastel.yellow('Ready') } State"
          modules.map! do |module_config|
            module_config.pod = kube_client.get_pods(label_selector: "run=#{module_config.name}").first
            module_config
          end

          module_names = modules.map(&:name)
          ready_module_names = []
          until module_names.sort == ready_module_names.sort
            modules.map! do |module_config|
              module_config.pod = kube_client. get_pods(label_selector: "run=#{module_config.name}").first
              if !ready_module_names.include?(module_config.name) &&
                 module_config&.pod&.status&.containerStatuses&.map(&:ready)&.all?
                ready_module_names << module_config.name
                put_bullet "[ #{success_mark} ] #{module_config.name}"
              end
              module_config
            end
            sleep 1
          end

          return modules
        end

        def resolve_module_dependencies(modules)
          put_task "Resolving Module Dependencies"

          # We can generate a list of compatible dependencies closest
          # to the versions, if any, that we provided in our config file.  We
          # levereage the `simulate=true` query param to do a "dry-run" install
          put_info "Desired:"
          modules.each do |module_config|
            put_bullet "#{module_config.name} : #{ module_config.tag ? module_config.tag : 'latest' }"
          end

          module_versions = okapi.post '/_/proxy/tenants/fs/install?simulate=true',
                                       modules.map(&:installation_payload).map(&:to_hash)

          put_info "Resolved:"
          module_versions.each do |version|
            # Extract the module name and tag from the
            # dependency resolution response
            version = version.to_hashugar
            module_matches = /(mod-\D*)(.*)/.match(version.id)
            module_name = module_matches[1].chomp('-')
            module_tag = module_matches[2]

            # Inject the resolved versions back into the
            # module structures
            modules.map! do |module_config|
              if module_config.name == module_name
                module_config.tag = module_tag
              end
              module_config
            end
            put_bullet "#{module_name} : #{ pastel.yellow(module_tag) }"
          end

          return modules
        end

        def create_tenant
          put_task "Creating Tenant: #{ pastel.yellow(configatron.tenant) }"
          shell.run!("kubectl apply -f #{project_root}/kubernetes/jobs/create-tenant.yaml")
        end

        def create_admin_user
          put_task "Creating 'admin' User"
          apply_from_template(
            "#{project_root}/kubernetes/jobs/create-admin-user.tmpl.yaml",
            'create-admin-user',
            storage: configatron.storage
          )
          sleep 5
        end

        def pull_registry
          put_task "Pulling Module Registration Info"
          put_warning "This operation will take approximately 10 minutes.  Grab a coffee."

          sleep 10

          # TODO: use a readiness check instead of a hardcoded sleep
          # the post below will timeout, so we need to trap that.
          # another option would be to add support for a custom timeout
          # in okapi.rb.
          begin
            okapi.post '/_/proxy/pull/modules', { urls: [ configatron.registry ] }
          rescue
            sleep 500
          end
        end

        def discover_modules(modules)
          # Once modules are registered, they must be discovered.  This
          # essentially makes a module available for installation by a tenant.
          put_task "Discovering Modules"
          modules.each do |module_config|
            service_address = kube_client.get_services(
              label_selector: "run=#{module_config.name}"
            ).first.spec.clusterIP

            service_port = kube_client.get_services(
              label_selector: "run=#{module_config.name}"
            ).first.spec.ports.first.port

            deployment_descriptor = {
              srvcId: "#{module_config.name}-#{module_config.tag}",
              instId: "#{module_config.name}-#{module_config.tag}",
              url: "http://#{service_address}:#{service_port}"
            }

            okapi.post '/_/discovery/modules', deployment_descriptor

            put_bullet "#{module_config.name}-#{module_config.tag} " \
                       "#{ pastel.yellow('->') } " \
                       "http://#{service_address}:#{service_port}"
          end
        end

        def enable_modules_for_tenant(modules, tenant)
          put_task "Enabling Modules for Tenant: #{ pastel.yellow(tenant) }"

          installations = modules.map do |module_config|
            { id: "#{module_config.name}-#{module_config.tag}", action: 'enable' }
          end
          okapi.post "/_/proxy/tenants/fs/install", installations
        end

        def apply_from_template(template_file, manifest_name, options={})
          # Store the result of the rendered template in a Tempfile
          # since `kubectl` likes to consume files.
          temp_file = Tempfile.new("#{manifest_name}:#{Time.now.to_i}")

          # Tilt is like MultiJson for templating languages
          template = Tilt::ERBTemplate.new(template_file)
          manifest = template.render(nil, options)

          # Populate, apply, and then destroy the manifest
          temp_file << manifest
          temp_file.flush
          shell.run!("kubectl apply -f #{temp_file.path}")
          temp_file.close
        end
      end
    end
  end
end
