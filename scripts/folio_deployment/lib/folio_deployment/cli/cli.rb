# coding: utf-8
require_rel 'commands'
require_rel 'utils'

module FolioDeployment
  module CLI
    class Main < FolioDeployment::CLI::Commands::Base
      subcommand "deploy", "Deploy FOLIO to a kubernetes cluster", FolioDeployment::CLI::Commands::Deploy
      subcommand "destroy", "Teardown the entire FOLIO cluster", FolioDeployment::CLI::Commands::Destroy
    end
  end
end
