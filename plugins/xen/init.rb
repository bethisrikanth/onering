require 'controller'
require 'assets/models/device'

module App
  class Base < Controller
    namespace '/api/xen' do
      get '/sync' do 
        hosts = {}

        Device.urlsearch('xen.uuid').to_a.each do |guest|
          uuid = guest.properties.get('xen.uuid')
          parent = (hosts[uuid] || Device.urlsearch("xen.guests/#{uuid}").to_a.first)

          if parent
          # cache the parent for the duration of this call
            hosts[uuid] ||= parent
            
            guest.parent_id = parent.id
            guest.save
          end
        end

        200
      end
    end
  end
end
