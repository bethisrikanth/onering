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

require 'controller'
require 'assets/models/asset'
require 'nagios/models/nagios_host'
require 'open-uri'

module App
  class Base < Controller
    namespace '/api/nagios' do
      post '/sync' do
        data = (MultiJson.load(request.env['rack.input'].read) rescue nil)
        return 400 unless json

        queued = Automation::Tasks::Task.run('nagios/sync', data)
        return 500 unless queued
        return 200
      end

      get '/alerts' do
        nagios_hosts = NagiosHost.search({
          'alerts.current_state' => {
            '$regex' => '^(warning|critical)$'
          }
        }).to_a

        return 404 if nagios_hosts.empty?

        rv = []

        devices = Asset.find(nagios_hosts.collect{|i| i['_id'] })

        nagios_hosts.each do |nagios|
          device_i = devices.find_index{|i| i['_id'] == nagios['_id'] }

          if device_i
            nagios['alerts'].each do |alert|
              alert['device'] = {
                'id'           => devices[device_i]['_id'],
                'name'         => devices[device_i]['name'],
                'aliases'      => devices[device_i]['aliases'],
                'tags'         => devices[device_i]['tags'],
                'status'       => devices[device_i]['status'],
                'collected_at' => devices[device_i]['collected_at']
              }

              alert['device']['properties'] = {
                'notes' => devices[device_i]['properties']['notes']
              } if devices[device_i] and devices[device_i]['properties']

              rv << alert
            end
          end
        end

        rv.to_json
      end

      get '/:id' do
        nagios_host = NagiosHost.find(params[:id])
        return 404 unless nagios_host
        rv = nagios_host.to_h

        if Config.get('nagios.url')
          rv['alerts'].each_with_index do |alert, i|
            name = URI::encode(rv['name'])
            type = (alert['type'] == 'service' ? 2 : 1)
            ext  = (alert['type'] == 'service' ? '&service='+URI::encode(alert['name']) : '')

            rv['alerts'][i]['url'] = "#{Config.get('nagios.url')}/nagios/cgi-bin/extinfo.cgi?type=#{type}&host=#{name}#{ext}"
          end
        end

        rv.to_json
      end
    end
  end
end
