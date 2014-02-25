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

require 'assets/models/asset'
require 'snmp/lib/util'
require 'snmp/models/snmp_host'

module Automation
  module Tasks
    module Snmp
      class Discover < Task
        extend App::Helpers::Snmp::Util

        DEFAULT_PING_TIMEOUT = 1.0
        DEFAULT_SNMP_TIMEOUT = 3.5

        require 'net/ping'
        require 'snmp'
        require 'digest'
        require 'socket'

        def self.perform(*args)
          @config = App::Config.get!('snmp')

          # queue = EM::Queue.new()
          processed_addresses = Set.new()

          @config.get('profiles',[]).each do |name, profile|
            profile = apply_profile_defaults(@config, profile)

            unless profile.get('enabled', true)
              log("Skipping profile #{name} as it was explicitly disabled")
              next
            end

            log("Discovering profile #{name}")

            discover_addresses = profile.get('discovery.addresses',[])

            if discover_addresses.empty?
              warn("No addresses configured for discovery in profile #{name}")
              return false
            end

            discover_addresses.each do |address|
              next if processed_addresses.include?(address)

              EM.run do
                debug("EventMachine reactor started")

                mutex, cv = SnmpHost.discover(address, {
                  :ping => {
                    :timeout => profile.get('protocol.ping_timeout', DEFAULT_PING_TIMEOUT),
                    :port    => 161
                  },
                  :snmp => {
                    :timeout   => profile.get('protocol.timeout', DEFAULT_SNMP_TIMEOUT),
                    :port      => profile.get('protocol.port', 161),
                    :community => profile.get('protocol.community', 'public'),
                    :oids      => profile.get('discovery.oids', [])
                  }
                }) do |discovered_host|
                  debug("Host #{discovered_host[:id]} is up and responding to SNMP queries")

                  catch(:skip) do
                    profile.get('discovery.filter',{}).each do |oid, pattern|
                      throw :skip unless discovered_host[:properties].keys.include?(oid)
                      throw :skip unless discovered_host[:properties][oid] =~ Regexp.new(pattern)
                    end

                    info("Saving host identification #{discovered_host.get(:id)}")

                    SnmpHost.new({
                      :profile => name
                    }.merge(discovered_host)).save()
                  end
                end

              # wait for the signal to continue
                mutex.synchronize do
                  cv.wait(mutex)
                end

                EM::stop_event_loop()
              end
            end

          end

          return nil
        end
      end
    end
  end
end
