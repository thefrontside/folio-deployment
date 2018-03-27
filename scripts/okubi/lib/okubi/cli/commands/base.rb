module Okubi
  module CLI
    module Commands
      class Base < Clamp::Command

        include Okubi::CLI::Utils::UserInterface
        include Okubi::CLI::Utils::Configurable

        # attr_accessor :environment, :project_root

        option '--environment', "ENVIRONMENT",
               'The environment to act against',
               required: true

        option '--version', :flag, 'show version' do
          puts 'folio-deployment-0.0.2a'
          exit 0
        end

        def execute
          load_configuration(environment)
        end
      end
    end
  end
end
