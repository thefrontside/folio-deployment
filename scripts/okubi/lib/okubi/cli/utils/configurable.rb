module Okubi
  module CLI
    module Utils
      module Configurable

        def load_configuration(environment)
          put_task 'Loading Configuration'

          configatron.configure_from_hash(
            Psych.load_file("#{project_root}/folio.conf")
          )

          if configatron[environment]
            scoped_config = configatron[environment].to_h
            configatron.reset!
            configatron.configure_from_hash(scoped_config)
          else
            put_error "Environment \"#{pastel.yellow(environment)}\" was not found in #{pastel.yellow('folio.conf')}"
          end

          # Default values are set here for now
          configatron.okapi.tag ||= 'latest'
          configatron.tenant ||= 'fs'
        end

      end
    end
  end
end
