require 'assets/models/asset'
require 'snmp/lib/util'
require 'snmp/models/snmp_host'

module Automation
  module Tasks
    module Snmp
      class Discover < Base
        include App::Helpers::Snmp::Util

        DEFAULT_PING_TIMEOUT = 1.0
        DEFAULT_SNMP_TIMEOUT = 3.5

        require 'net/ping'
        require 'snmp'
        require 'digest'
        require 'socket'

        def run(request)
          @config = App::Config.get!('snmp')

          queue = EM::Queue.new()
          processed_addresses = Set.new()

          @config.get('profiles',[]).each do |name, profile|
            profile = apply_profile_defaults(@config, profile)

            unless profile.get('enabled', true)
              log("Skipping profile #{name} as it was explicitly disabled")
              next
            end

            log("Discovering profile #{name}")

            profile.get('discovery.addresses',[]).each do |address|
              next if processed_addresses.include?(address)

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

                catch(:skip) do
                  profile.get('discovery.filter',{}).each do |oid, pattern|
                    throw :skip unless discovered_host[:properties].keys.include?(oid)
                    throw :skip unless discovered_host[:properties][oid] =~ Regexp.new(pattern)
                  end

                  log("Saving host identification #{discovered_host.get(:id)}")

                  SnmpHost.new({
                    :profile => name
                  }.merge(discovered_host)).save()
                end
              end

            # wait for the signal to continue
              mutex.synchronize do
                cv.wait(mutex)
              end
            end

          end

          return nil
        end
      end
    end
  end
end
