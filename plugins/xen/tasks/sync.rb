require 'assets/models/asset'

module Automation
  module Tasks
    module Xen
      class Sync < Base
        def run(request)
          hosts = {}

          guests = Asset.urlquery('xen.uuid').to_a

          if not guests.empty?
            log("Linking #{guests.length} Xen guests to their parent hosts")

            guests.each do |guest|
              uuid = guest.properties.get('xen.uuid')
              parent = (hosts[uuid] || Asset.urlquery("xen.guests/#{uuid}").to_a.first)

              if parent
              # cache the parent for the duration of this call
                hosts[uuid] ||= parent

                guest.parent_id = parent.id
                guest.save()
              end
            end
          end

          return nil
        end
      end
    end
  end
end
