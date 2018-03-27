module Okubi
  module CLI
    module Operations
      class DeployOkapi < Operation
        # attr_reader :environment

        def task_name
          'Deploying Okapi'.freeze
        end

        def call
          put_task task_name

          put_info "Applying Kubernetes Manifest"

          # To be revisited. The Okapi Dockerfile doesn't include an entrypoint,
          # nor does it seem to work out of the box.  Generally when Okapi
          # is started it requires a command and takes options, but that
          # never seems to happen and the logs show Okapi carping about the
          # lack of command.  We may have to go back to building our own Okapi
          # images with augmented Dockerfiles.

          apply_from_template(
            "#{project_root}/kubernetes/okapi/okapi.tmpl.yaml",
            'okapi',
            okapi: configatron.okapi,
            storage: configatron.storage
          )

          sleep 10

          # Wait until Okapi is "Ready" before proceeding
          put_info "Waiting for Okapi Pod to Achieve #{ pastel.yellow('Ready') } State"
          okapi_pod = kube_client.get_pods(label_selector: 'run=okapi').first
          until okapi_pod && okapi_pod.status.containerStatuses.map(&:ready).all? do
            okapi_pod = kube_client.get_pods(label_selector: 'run=okapi').first
            sleep 10
          end
        end
      end
    end
  end
end
