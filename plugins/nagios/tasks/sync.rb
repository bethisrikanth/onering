require 'set'
require 'assets/models/asset'
require 'nagios/models/nagios_host'

module Automation
  module Tasks
    module Nagios
      class Sync < Task
        def self.perform(alerts)
          fail("Alert data is required to run this task") if alerts.nil?
          fail("Malformed alert data: expected Hash, got #{alerts.class.name}") unless alerts.is_a?(Hash)

          NagiosHost.delete_all()

          alerting_ids = Asset.ids("alert_state/not:null")
          new_alerts = Set.new()

          unless alerts.empty?
            info("Updating hosts with #{alerts.length} Nagios alerts")

            alerts.each do |host, states|
            # skip hostnames that aren't strings for some reason
              host = host.strip.chomp rescue next

            # remove checks where notifications are disabled
              states['alerts'].reject!{|i| !i['notify'] }

            # if this host has alerts
              unless states['alerts'].empty?
                node = Asset.urlquery("name:aliases:dns.name/#{host}").first
                next unless node

                nagios_host = NagiosHost.find(node.id)
                nagios_host = NagiosHost.new({
                  :id => node.id
                }) unless nagios_host

                begin
                  nagios_host.from_hash(states, false).save()
                rescue Exception => e
                  error("Failed to save check data for host #{node.id}")
                  next
                end

              # order (host U service) by state[critical, warning, *], then take
              # the first result and grab its state; will be the worst of the set
                worst_state = (((states['alerts'].sort{|a,b|
                  (a[:current_state] == :critical ? 0 : (a[:current_state] == :warning ? 1 : 2)) <=> (b[:current_state] == :critical ? 0 : (b[:current_state] == :warning ? 1 : 2))
                }).flatten.first['current_state'] || nil) rescue nil)

                node.set(:alert_state, worst_state)
                node.save()

                new_alerts << node.id
              end
            end
          end

        # cleanup slate alerts
          cleanup = (alerting_ids - new_alerts.to_a)

          log("Marking #{cleanup.length} nodes as healthy")

          cleanup.each do |id|
            begin
              Asset.find(id).set(:alert_state, nil).save()
            rescue Exception => e
              error("Could not mark node #{id} healthy: #{e.message}", e.class.name)
              next
            end
          end

          return true
        end
      end
    end
  end
end
