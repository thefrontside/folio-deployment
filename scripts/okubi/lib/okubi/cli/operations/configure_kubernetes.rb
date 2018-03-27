module Okubi
  module CLI
    module Operations
      class ConfigureKubernetes < Operation
        attr_reader :environment

        def task_name
          'Configuring Kubernetes'.freeze
        end

        def initialize(context:)
          @environment = context
        end

        def call
          put_task task_name

          put_info "Setting Context: #{pastel.yellow(environment)}"

          shell.run!("kubectl config use-context #{environment}")

          # TODO: check if one is already running and kill it first
          put_info "Killing Running 'kubectl' Processes"
          shell.run!('sudo killall -9 kubectl &> /dev/null')

          put_info "Starting Kubernetes Proxy"
          kubectl_pid = fork do
            exec 'kubectl proxy &> /dev/null'
          end
          put_info "Started `kubectl proxy` at PID #{pastel.yellow(kubectl_pid)}"
          sleep 2

          # TODO: kill the spawned process at end of execution
          put_info "Connecting To Kubernetes"
          kube_client.discover
        end
      end
    end
  end
end
