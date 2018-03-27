module Okubi
  module CLI
    module Operations
      class ConfigureIngress < Operation

        TASK_NAME = 'Configuring Ingress'.freeze

        def call
          put_task TASK_NAME

          put_info 'Deploying Ingress Object'

          apply_from_template(
            "#{project_root}/kubernetes/ingress/ingress.tmpl.yaml",
            'ingress',
            host: URI(configatron.host).host
          )

          put_info "Creating 'kube-lego' Namespace"
          shell.run!("kubectl apply -f #{project_root}/kubernetes/ingress/lego/00-lego-namespace.yaml")

          put_info 'Configuring \'kube-lego\' Certificate Manager'
          shell.run!("kubectl apply -f #{project_root}/kubernetes/ingress/lego/lego-configmap.yaml")

          put_info 'Deploying \'kube-lego\' Certificate Manager'
          shell.run!("kubectl apply -f #{project_root}/kubernetes/ingress/lego/lego.yaml")

          put_info "Enabling TLS Termination (HTTPS)"

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
      end
    end
  end
end
