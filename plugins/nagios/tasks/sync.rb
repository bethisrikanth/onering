require 'assets/models/device'
require 'nagios/models/nagios_host'

module Automation
  module Tasks
    module Nagios
      class Sync < Base
        def run(request)
          fail("Data is required to run this task") if @data.nil?

          if @data.is_a?(String)
            @data = MultiJson.load(@data)
          end

          fail("Data must be a valid JSON document") unless @data.is_a?(Hash)

          NagiosHost.delete_all()
          Device.set({
            'properties.alert_state' => {'$exists' => 1}
          }, {
            'properties.alert_state' => nil
          })

          if @data.empty?
            log("No hosts to update")
          else
            log("Updating hosts with #{@data.length} Nagios alerts")
          end

          @data.each do |host, states|
          # skip hostnames that aren't strings for some reason
            host = host.strip.chomp rescue next

          # remove checks where notifications are disabled
            states['alerts'].reject!{|i| !i['notify'] }

          # if this host has alerts
            unless states['alerts'].empty?
              device = Device.where({
                '$or' => [{
                  'name' => {
                    '$regex' => "^#{host}.*$",
                    '$options' => 'i'
                  }
                },{
                  'aliases' => {
                    '$regex' => "^#{host}.*$",
                    '$options' => 'i'
                  }
                }]
              }).limit(1).to_a.first

              if device
                nagios_host = NagiosHost.find_or_create(device.id)
                begin
                  nagios_host.from_json(states, false).safe_save
                rescue Exception => e
                  log("Failed to save check data for host #{device.id}, skipping", :error)
                  next
                end

              # order (host U service) by state[critical, warning, *], then take
              # the first result and grab its state; will be the worst of the set
                worst_state = (((states['alerts'].sort{|a,b|
                  (a[:current_state] == :critical ? 0 : (a[:current_state] == :warning ? 1 : 2)) <=> (b[:current_state] == :critical ? 0 : (b[:current_state] == :warning ? 1 : 2))
                }).flatten.first['current_state'] || nil) rescue nil)

                device.properties = {} unless device.properties
                device.properties['alert_state'] = worst_state
                device.safe_save
              end
            end

            nil
          end
        end
      end
    end
  end
end
