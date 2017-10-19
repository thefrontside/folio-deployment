# coding: utf-8
require_rel 'commands'

module FolioDeployment
  module CLI
    class Main < FolioDeployment::CLI::Commands::Base
      subcommand "deploy", "Deploy FOLIO to a kubernetes cluster", FolioDeployment::CLI::Commands::Deploy
    end
  end
end
