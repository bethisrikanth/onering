require 'controller'
require 'assets/models/device'
require 'nagios/models/nagios_host'

module App
  class Base < Controller
    namespace '/api/nagios' do
      post '/sync' do
        json = JSON.parse(request.env['rack.input'].read)
        if json.is_a?(Hash)
          NagiosHost.delete_all

          json.each do |host, states|
            host = host.strip.chomp rescue next

            device = Device.where({
              'name' => {
                '$regex' => "^#{host}.*$",
                '$options' => 'i'
              }
            })

            if device.to_a.length == 1
              nagios_host = NagiosHost.find_or_create(device.first.id)
              nagios_host.from_json(states, false).safe_save
            end
          end
        end

        200
      end
    end
  end
end
