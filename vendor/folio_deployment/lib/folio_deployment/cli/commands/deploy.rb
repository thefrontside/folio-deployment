# require 'pry-byebug'
# require 'erb'
# require 'tempfile'

module FolioDeployment
  module CLI
    module Commands
      class Deploy < Base
         def execute
           put_command "Deploying FOLIO"

           load_configuration
           configure_kubernetes

           public_address = deploy_ingress_controller
           configure_dnsimple(public_address)
           deploy_okapi
           deploy_ingress
           deploy_lego
           enable_ingress_tls

           create_tenant

           # TODO: this sometimes hits a timeout.  maybe we shouldn't pull
           # it every single time.
           pull_registry

           # Here we split the modules into those being pulled from images
           # and those being built from source with folio-toolkit
           modules, source_modules, image_modules = prepare_modules
           deploy_image_modules(image_modules)
           deploy_source_modules(source_modules)

           # NOTE: source-built images automatically register
           # and then discover themselves
           discover_modules(image_modules)

           # But all modules need to be enabled for tenant from here
           enable_modules_for_tenant(modules, configatron.tenant)
           create_admin_user

           put_success "FOLIO Successfully Deployed"
           shell_out.run!("kubectl get all")
           exit 0
         end

         def deploy_ingress_controller
           put_task "Deploying NGINX Ingress Controller"

           put_info "Create 'nginx-ingress' Namespace"
           shell.run!('kubectl apply -f kubernetes/ingress/nginx/00-nginx-namespace.yaml')

           put_info "Deploying Default HTTP Backend"
           shell.run!("kubectl apply -f kubernetes/ingress/nginx/default-http-backend.yaml")

           put_info "Deploying NGINX"
           shell.run!('kubectl apply -f kubernetes/ingress/nginx/nginx-ingress-controller.yaml')

           put_info "Waiting For Public Address"
           sleep 5

           nginx = client.get_service 'nginx-ingress-controller', 'nginx-ingress'
           until (public_address = nginx&.status&.loadBalancer&.ingress&.first&.ip)
             nginx = client.get_service 'nginx-ingress-controller', 'nginx-ingress'
             sleep 5
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
           shell.run!('kubectl apply -f kubernetes/ingress/lego/00-lego-namespace.yaml')

           put_info "Configuring Lego"
           shell.run!("kubectl apply -f kubernetes/ingress/lego/lego-configmap.yaml")

           put_info "Deploying Lego"
           shell.run!('kubectl apply -f kubernetes/ingress/lego/lego.yaml')
         end

         def deploy_ingress
           put_task "Deploying Ingress"
           shell.run!('kubectl apply -f kubernetes/ingress/ingress.yaml')
         end

         def enable_ingress_tls
           put_task "Enabling TLS Termination (HTTPS)"
           shell.run!('kubectl apply -f kubernetes/ingress/ingress-tls.yaml')

           put_info "Verifying Certificate for #{configatron.host}"
           until SSLTest.test(configatron.host)[0]
             sleep 3
           end
         end

         def deploy_okapi
           put_task "Deploying Okapi"
           options ={
             okapi: configatron.okapi,
             storage: configatron.storage
           }

           put_info "Applying Kubernetes Manifest"
           shell.run!("kubectl apply -f kubernetes/okapi.yaml")

           sleep 10

           # Wait until Okapi is "Ready" before proceeding
           put_info "Waiting for Okapi Pod to Achieve #{ pastel.yellow('Ready') } State"
           okapi_pod = client.get_pods(label_selector: 'run=okapi').first
           until okapi_pod && okapi_pod.status.containerStatuses.map(&:ready).all? do
             okapi_pod = client.get_pods(label_selector: 'run=okapi').first
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
               installation_payload: installation_payload
             )
           end

           # Split into modules we're building from source and module we're
           # pulling from a container registry
           source_modules = modules.select { |module_config| module_config.manifest }
           image_modules = modules - source_modules
           # binding.pry
           return modules, source_modules, image_modules
         end

         def deploy_image_modules(modules)
           put_task "Deploying FOLIO Modules"

           modules = resolve_module_dependencies(modules)

           # Inject appropriate values into a Kubernetes manifest template
           # according to what was found in `folio.conf`, then apply
           # the manifests to the cluster.  If the corresponding resoures
           # already exist, any change should trigger a RollingUpdate
           put_info "Applying Kubernetes Manifests"
           modules.each do |folio_module|
             apply_folio_module_template(
               './kubernetes/templates/folio-module-template.yaml',
               {
                 folio_module: folio_module,
                 storage: configatron.storage
               }
             )
             put_bullet "#{folio_module.name}"
           end

           # Here we use the kubeclient gem to monitor the status of the Pods
           # that were erected by the Deployments we just applied.  Pods contain
           # multiple containers, and must be completely ready and healthy before
           # we proceed with discovery.
           put_info "Waiting for Module Pods to Achieve #{ pastel.yellow('Ready') } State"
           modules.map! do |module_config|
             module_config.pod = client.get_pods(label_selector: "run=#{module_config.name}").first
             module_config
           end

           module_names = modules.map(&:name)
           ready_module_names = []
           until module_names.sort == ready_module_names.sort
             modules.map! do |module_config|
               module_config.pod = client. get_pods(label_selector: "run=#{module_config.name}").first
               if !ready_module_names.include?(module_config.name) &&
                  module_config.pod.status.containerStatuses.map(&:ready).all?
                 ready_module_names << module_config.name
                 put_bullet "[ #{success_mark} ] #{module_config.name}"
               end
               module_config
             end
             sleep 1
           end

           return modules
         end

         def deploy_source_modules(modules)
           put_task "Building FOLIO Modules From Source"

           modules.each do |folio_module|
             put_bullet "#{folio_module.name} : (#{pastel.yellow(folio_module.manifest)})"
             shell.run!("kubectl apply -f #{folio_module.manifest}")
           end

           # TODO: un-copypasta
           put_info "Waiting for Module Pods to Achieve #{ pastel.yellow('Ready') } State"
           modules.map! do |module_config|
             module_config.pod = client.get_pods(label_selector: "run=#{module_config.name}").first
             module_config
           end

           module_names = modules.map(&:name)
           ready_module_names = []
           until module_names.sort == ready_module_names.sort
             modules.map! do |module_config|
               module_config.pod = client. get_pods(label_selector: "run=#{module_config.name}").first
               if !ready_module_names.include?(module_config.name) &&
                  module_config.pod.status.containerStatuses.map(&:ready).all?
                 ready_module_names << module_config.name
                 put_bullet "[ #{success_mark} ] #{module_config.name}"
               end
               module_config
             end
             sleep 1
           end

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
           # binding.pry
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
           shell.run!("kubectl apply -f kubernetes/jobs/create-tenant.yaml")
         end

         def create_admin_user
           put_task "Creating 'admin' User"
           shell.run!("kubectl apply -f kubernetes/jobs/create-admin-user.yaml")
           sleep 5
         end

         def pull_registry
           put_task "Pulling Module Registration Info"
           okapi.post '/_/proxy/pull/modules', { urls: [ "http://folio-registry.aws.indexdata.com:9130" ] }
         end

         def discover_modules(modules)
           # Once modules are registered, they must be discovered.  This
           # essentially makes a module available for installation by a tenant.
           put_task "Discovering Modules"
           modules.each do |module_config|
             service_address = client.get_services(
               label_selector: "run=#{module_config.name}"
             ).first.spec.clusterIP

             service_port = client.get_services(
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

         def load_configuration
           put_task "Loading Configuration"

           configatron.configure_from_hash(Psych.load_file('./folio.conf'))

           # Default values are set here for now
           configatron.okapi.tag ||= 'latest'
           configatron.tenant ||= 'fs'
         end

         def apply_folio_module_template(template_file, options={})
           storage = options[:storage]
           folio_module = options[:folio_module]

           tmp = Tempfile.new("#{folio_module.name}:#{Time.now.to_i}")
           tmp << ERB.new(File.read(template_file)).result(binding)
           tmp.flush
           shell.run!("kubectl apply -f #{tmp.path}")
           tmp.close
         end

         def apply_okapi_template(template_file, options={})
           storage = options[:storage]
           okapi = options[:okapi]

           tmp = Tempfile.new("okapi:#{Time.now.to_i}")
           tmp << ERB.new(File.read(template_file)).result(binding)
           tmp.flush
           shell_out.run!("kubectl apply -f #{tmp.path}")
           tmp.close
         end

         def configure_kubernetes
           put_task "Configuring Kubernetes"
           put_info "Setting Context: #{ pastel.yellow(configatron.context) }"

           shell.run!("kubectl config use-context #{configatron.context}")

           # TODO: check if one is already running and kill it first
           put_info "Starting Kubernetes Proxy"
           fork do
             exec 'kubectl proxy &> /dev/null'
           end
           sleep 2

           put_info "Connecting To Kubernetes"
           client.discover
         end
       end
    end
  end
end
