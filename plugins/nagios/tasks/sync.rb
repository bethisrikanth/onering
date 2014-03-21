# Copyright 2012 Outbrain, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'set'
require 'assets/models/asset'
require 'nagios/models/nagios_host'

module Automation
  module Tasks
    module Nagios
      class Sync < Task
        def self.perform(alerts, *args)
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
                node = Asset.urlquery("name|aliases|dns.name/#{host}").first
                next unless node

                debug("Found node #{node.id} for Nagios host #{host}")

                nagios_host = NagiosHost.find(node.id)
                nagios_host = NagiosHost.new({
                  :id => node.id
                }) unless nagios_host

                begin
                  nagios_host.update(states).save()
                rescue Exception => e
                  error("Failed to save check data for host #{node.id}: #{e.class.name} - #{e.message}")
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

        # cleanup stale alerts
          cleanup = (alerting_ids - new_alerts.to_a).uniq()

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
