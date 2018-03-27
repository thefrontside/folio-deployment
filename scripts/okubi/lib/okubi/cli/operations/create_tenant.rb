module Okubi
  module CLI
    module Operations
      class CreateTenant < Operation

        def task_name
          "Creating Tenant: #{ pastel.yellow(configatron.tenant) }"
        end

        def call
          put_task task_name
          shell.run!("kubectl apply -f #{project_root}/kubernetes/jobs/create-tenant.yaml")
        end
      end
    end
  end
end
