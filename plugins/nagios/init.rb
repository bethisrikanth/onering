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
          Device.set({
            'properties.alert_state' => {'$exists' => 1}
          }, {
            'properties.alert_state' => nil
          })

          json.each do |host, states|
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
                nagios_host.from_json(states, false).safe_save

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
          end
        end

        200
      end

      get '/:id' do
        nagios_host = NagiosHost.find(params[:id])
        return 404 unless nagios_host
        nagios_host.to_json
      end
    end
  end
end
