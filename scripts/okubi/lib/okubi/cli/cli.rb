require_rel 'operations'
require_rel 'commands'
require_rel 'utils'

module Okubi
  module CLI
    class Main < Okubi::CLI::Commands::Base

      subcommand 'deploy', 'Deploy FOLIO to a kubernetes cluster',
                 Okubi::CLI::Commands::Deploy

      subcommand 'destroy', 'Teardown the entire FOLIO cluster',
                 Okubi::CLI::Commands::Destroy
    end
  end
end
