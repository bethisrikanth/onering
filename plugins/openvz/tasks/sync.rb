require 'assets/models/device'

module Automation
  module Tasks
    module Openvz
      class Sync < Base
        def run(request)
          hosts = Device.urlsearch('openvz.guests').to_a


          if not hosts.empty?
            log("Found #{hosts.length} OpenVZ hosts")

            hosts.each do |host|
              log("Linking guests for #{host.name} (#{host.id})")

              host.get('openvz.guests').each do |guest_name|
                guest = Device.urlsearch("fqdn/#{guest_name}").to_a.select{|i| i.get('virtual').to_s === 'true' }

                case guest.length
                when 0
                  log("Cannot find guest #{guest_name}")
                when 1
                  guest = guest.first
                  guest.parent_id = host.id
                  guest.save

                else
                  log("Found too many guests named #{guest_name}, cannot determine which one to link")
                end
              end
            end
          end

          nil
        end
      end
    end
  end
end
