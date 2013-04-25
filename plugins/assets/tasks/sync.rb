require 'assets/models/device'
require 'assets/models/node_default'

module Automation
  module Tasks
    module Assets
      class Sync < Base
        def run(request)
          rv = {
            :success => 0,
            :time    => Time.now,
            :errors  => []
          }

        # resync defaults
          NodeDefault.all.each do |default|
            devices = default.devices.to_a
            next unless devices.length > 0

            log("Resyncing #{devices.length} nodes with rule: #{default.name}", :info)

            devices.each do |device|
              begin
              # resave the device to apply the defaults to it
                device.safe_save
                rv[:success] += 1
              rescue Exception => e
                log("Error resyncing #{device.id}: #{e.class.name} - #{e.message}", :warning)

                rv[:errors] << {
                  :id      => device.id,
                  :message => e.message
                }
              end
            end
          end

          rv[:time] = (Time.now - rv[:time]).to_f

          log("No devices required sync") if rv[:success] == 0

          return rv
        end
      end
    end
  end
end