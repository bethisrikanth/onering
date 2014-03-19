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
        return 400 unless data

        queued = Automation::Tasks::Task.run('nagios/sync', data)
        return 500 unless queued
        return 200
      end

      get '/alerts' do
        nagios_hosts = NagiosHost.urlquery("alerts.current_state/warning|critical")
        return 404 if nagios_hosts.empty?

        rv = []

        assets = Asset.find(nagios_hosts.collect{|i| i.id })

        nagios_hosts.each do |nagios|
          asset_index = devices.find_index{|i| i.id == nagios.id }

          if asset_index
            nagios.alerts.each do |alert|
              alert['device'] = {
                'id'           => assets[asset_index].id,
                'name'         => assets[asset_index].name,
                'aliases'      => assets[asset_index].aliases,
                'tags'         => assets[asset_index].tags,
                'status'       => assets[asset_index].status,
                'collected_at' => assets[asset_index].collected_at
              }

              alert['device']['properties'] = {
                'notes' => assets[asset_index]['properties']['notes']
              } if assets[asset_index] and assets[asset_index]['properties']

              rv << alert
            end
          end
        end

        output(rv.to_json())
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

            rv['alerts'][i]['url'] = "#{App::Config.get('nagios.url')}/nagios/cgi-bin/extinfo.cgi?type=#{type}&host=#{name}#{ext}"
          end
        end

        rv.to_json
      end
    end
  end
end
