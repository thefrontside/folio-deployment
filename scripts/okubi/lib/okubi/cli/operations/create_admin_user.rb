module Okubi
  module CLI
    module Operations
      class CreateAdminUser < Operation

        TASK_NAME = 'Creating \'Admin\' User'.freeze

        def call
          put_task TASK_NAME

          apply_from_template(
            "#{project_root}/kubernetes/jobs/create-admin-user.tmpl.yaml",
            'create-admin-user',
            storage: configatron.storage
          )
          sleep 5
        end
      end
    end
  end
end
