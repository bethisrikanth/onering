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
          NodeDefault.urlquery('bool:enabled/true').each do |default|
            devices = default.devices.to_a
            next unless devices.length > 0

            log("Resyncing #{devices.length} nodes with rule: #{default.name}", :info)

            devices.each do |device|
              begin
              # resave the device to apply the defaults to it
                device.save()
                rv[:success] += 1

              rescue Interrupt
                raise abort("Manually interrupted")

              rescue Exception => e
                log("Error resyncing #{device.id}: #{e.class.name} - #{e.message}", :warning)
                e.backtrace.each do |backtrace|
                  next unless backtrace =~ /onering/
                  log("  #{backtrace}", :debug)
                end

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