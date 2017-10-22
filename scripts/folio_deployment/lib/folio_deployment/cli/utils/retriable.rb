module FolioDeployment
  module CLI
    module Utils
      module Retriable
        # Loosely based on this gist:
        # https://gist.github.com/suciuvlad/4078129

        # This helper makes use of ruby's `retry` feature to give
        # a line of code several shots at executing before giving up hope.
        # It's particularly useful when using `kubeclient` to get a resource.
        # I'm not clear on the specifics, but during the standing-up of a
        # resource there is sometimes a "flickering" effect where the resource
        # briefly drops off the radar.  Also a lifesaver while pulling
        # Module Descriptors from the central registry.

        def with_retries(options={}, &block)
          options[:limit] ||= 10
          options[:sleep] ||= 5

          retried = 0
          begin
            yield
          rescue Exception => e
            if retried + 1 < options[:limit]
              retried += 1
              sleep options[:sleep]
              puts "Retrying..."
              retry
            else
              raise e
            end
          end
        end
      end
    end
  end
end

# "Started at the bottom now we here"
class Object
  include FolioDeployment::CLI::Utils::Retriable
  extend FolioDeployment::CLI::Utils::Retriable
end
