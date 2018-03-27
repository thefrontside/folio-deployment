module Okubi
  module CLI
    module Operations
      class PullRegistry < Operation

        TASK_NAME = 'Pulling Module Descriptors From Central Repository'.freeze

        def call
          put_warning 'This operation will take approximately 10 minutes.  Grab a coffee.'

          sleep 10

          # TODO: use a readiness check instead of a hardcoded sleep
          # the post below will timeout, so we need to trap that.
          # another option would be to add support for a custom timeout
          # in okapi.rb.
          begin
            okapi.post '/_/proxy/pull/modules', { urls: [ configatron.registry ] }
          rescue
            sleep 500
          end
        end
      end
    end
  end
end
