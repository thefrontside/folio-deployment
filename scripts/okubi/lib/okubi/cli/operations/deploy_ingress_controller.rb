module Okubi
  module CLI
    module Operations
      class DeployIngressController < Operation
        # attr_reader :kube_client

        TASK_NAME = 'Deploying NGINX Ingress Controller'.freeze

        def call
          put_task TASK_NAME

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

          # TODO: make operations composable / chainable
          # capture return values some way other than configatron store
          # ConfigureDnsimple.new(host: configatron.host, public_address: configatron.public_address).call

          configatron.public_address = public_address
        end
      end
    end
  end
end
