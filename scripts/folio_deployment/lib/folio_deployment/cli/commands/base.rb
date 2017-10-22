# coding: utf-8
module FolioDeployment
  module CLI
    module Commands
      class Base < Clamp::Command

        include FolioDeployment::CLI::Utils::UserInterface
        # include FolioDeployment::CLI::Utils::Retriable

        attr_accessor :environment, :project_root

        def kube_client
          @kube_client ||= Kubeclient::Client.new("http://127.0.0.1:8001/api", 'v1')
        end

        def okapi
          @okapi ||= Okapi::Client.new(configatron.host, 'fs', nil)
        end

        def dnsimple_client
          @dnsimple_client = Dnsimple::Client.new(access_token: ENV['DNSIMPLE_TOKEN'])
        end

        option '--version', :flag, "show version" do
          puts "folio-deployment-0.0.1a"
          exit 0
        end

        def load_configuration(environment)
          put_task "Loading Configuration"

          @project_root = shell.run!('git rev-parse --show-toplevel').out.strip

          @environment = environment

          configatron.configure_from_hash(Psych.load_file("#{project_root}/folio.conf"))

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
