module FolioDeployment
  module CLI
    module Commands
      class Destroy < Base
        def execute
          put_command "Teardown FOLIO"
          shell_out.run!('kubectl delete deployments,services,pods,jobs,namespaces,ingresses --all')
        end
      end
    end
  end
end
