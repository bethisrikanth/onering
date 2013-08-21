require 'assets/models/asset'

module Automation
  module Tasks
    module Snmp
      class Sync < Base
        DEFAULT_PING_TIMEOUT = 0.5
        DEFAULT_SNMP_TIMEOUT = 3.5

        require 'net/ping'
        require 'snmp'

        def run(request)
          config = App::Config.get!('snmp')

          config.get('profiles',[]).each do |name, profile|
            log("Performing SNMP discovery for profile #{name}")
            profile = config.get('options.defaults',{}).deeper_merge!(profile)

            addresses = []

          # get addresses from a file, one address per line
            address_list = File.join(config.get('options.address_lists', File.join(ENV['PROJECT_ROOT'], 'config', 'snmp', 'addresses')), "#{name}.list")

            if File.exists?(address_list)
              list = File.read(address_list).lines.reject{|i|
                i = i.strip.chomp
                true if i.empty?
                true if i[0].chr == '#'
                false
              }.collect{|i|
                i.strip.chomp
              }

              log("Found #{list.length} addresses in file #{address_list}")
              addresses += list
            end

            processed_addresses = 0

          # perform discovery
            addresses.each do |address|
              query = proc do
                begin
                  port = (profile.get('protocol.port', 161)).to_i

                  if Net::Ping::ICMP.new(address, port, profile.get('protocol.ping_timeout', DEFAULT_PING_TIMEOUT).to_i).ping?
                    snmp = SNMP::Manager.new({
                      :host    => address,
                      :port    => port,
                      :timeout => profile.get('protocol.timeout', DEFAULT_SNMP_TIMEOUT)
                    })

                    filter = profile.get('filter', {})

                    unless filter.empty?
                      filter.each do |oid, pattern|
                        value = snmp.get_value(oid)
                        raise "Excluding #{address} because filter #{oid} does not match #{pattern}" unless value =~ Regexp.new(pattern)
                      end
                    end

                    log("DEBUG: #{address}, #{filter.inspect}")

                  end
                rescue
                  next
                ensure
                  processed_addresses += 1
                end
              end

              EM.defer(query)
            end

            while processed_addresses < addresses.length
              sleep 0.1
            end
          end


          # hosts = {}

          # guests = Asset.urlsearch('xen.uuid').to_a

          # if not guests.empty?
          #   log("Linking #{guests.length} Xen guests to their parent hosts")

          #   guests.each do |guest|
          #     uuid = guest.properties.get('xen.uuid')
          #     parent = (hosts[uuid] || Asset.urlsearch("xen.guests/#{uuid}").to_a.first)

          #     if parent
          #     # cache the parent for the duration of this call
          #       hosts[uuid] ||= parent

          #       guest.parent_id = parent.id
          #       guest.save
          #     end
          #   end
          # end



          return nil
        end
      end
    end
  end
end
