module Okubi
  module CLI
    module Operations
      class ConfigureDnsimple < Operation
        # attr_reader :public_address, :host, :dnsimple_client, :kube_client
        attr_reader :host, :public_address


        TASK_NAME = 'Configuring DNSimple'.freeze

        def initialize(host:, public_address:)
          @public_address = public_address
        end

        def call
          put_task TASK_NAME

          # Gather info required for DNSimple API
          uri = URI(configatron.host)
          record_name = uri.host.split('.')[0]
          zone_name = uri.host.split('.')[1..-1].join('.')

          account_id = dnsimple_client.identity.whoami.data.account.id
          record_id = dnsimple_client.zones.all_records(
            account_id,
            zone_name
          ).data.find { |record| record.name == record_name }.id


          put_info "Updating Record '#{uri.host}' -> #{public_address}"
          dnsimple_client.zones.update_record(
            account_id,
            'frontside.io',
            record_id,
            content: "#{public_address}"
          )

          put_info "Waiting for DNS refresh"
          until Resolv.getaddress(uri.host) == "#{public_address}"
            sleep 5
          end
        end
      end
    end
  end
end
