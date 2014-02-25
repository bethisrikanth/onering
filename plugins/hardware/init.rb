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
require 'hardware/models/rack'
require 'assets/models/asset'
require 'organization/models/contact'

module App
  class Base < Controller
    namespace '/api/hardware' do
      namespace '/sites' do
        get '/?' do
          sites = Config.get('hardware.sites', Asset.list(:site))

          output(sites.collect{|site|
            {
              :id => site,
              :contact => (Contact.urlquery("site/#{site}").to_a.first.to_hash() rescue nil),
              :racks   => Hardware::Rack.urlquery("site/#{site}").collect{|i|
                i.name
              }.sort,
              :summary => {

              }
            }.compact
          })
        end
      end

      namespace '/rack' do
        get '/:site/?' do
          output(Hardware::Rack.urlquery("site/#{params[:site]}").collect{|i|
            i.serializable_hash()
          }.sort{|a,b|
            a['name'] <=> b['name']
          })
        end


        get '/:site/:rack/?' do
          output(Hardware::Rack.urlquery("site/#{params[:site]}/name/#{params[:rack]}").first.serializable_hash())
        end


        post '/:site/:rack/?' do
          rack = Hardware::Rack.urlquery("site/#{params[:site]}/name/#{params[:rack]}").first
          rack = Hardware::Rack.new unless rack


          json = MultiJson.load(request.env['rack.input'].read)
          json.delete('units')
          json.set('site', params[:site])
          rack.from_hash(json).save()

          200
        end

        delete '/:site/:rack/?' do
          rack = Hardware::Rack.urlquery("site/#{params[:site]}/name/#{params[:rack]}").first
          return 404 unless rack
          return (rack.destroy() === true ? 200 : 500)
        end
      end
    end
  end
end
