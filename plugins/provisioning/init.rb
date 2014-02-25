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

require 'liquid_patches'
require 'controller'
require 'assets/models/asset'
require 'provisioning/models/asset_request'
require 'uri'
require 'net/http'

module App
  class Base < Controller
    configure do
      set :views, File.join(ENV['PROJECT_ROOT'], 'config', 'templates')
      ::Liquid::Template.file_system = ::Liquid::LocalFileSystem.new(settings.views)
    end

    helpers do
      def get_macs(asset)
        macs = []

        asset.properties.get('network.interfaces').each do |iface|
          if ['eth0', 'eth1'].include?(iface['name'])
            macs << {
              :interface => iface['name'],
              :mac       => iface['mac']
            } if iface['mac']
          end
        end

        return macs.sort{|a,b| a[:interface] <=> b[:interface] }
      end
    end

    namespace '/api/provision' do
      namespace '/request' do
        %w{
          /find/?
          /find/*
        }.each do |r|
          get r do#ne
            if params[:splat].nil?
              assets = AssetRequest.all()
            else
              k,v = params[:splat].first.split('/')
              assets = AssetRequest.urlquery({
                k => v
              }.join('/'))
            end

            return 404 unless assets
            output(assets.collect{|i| i.to_hash() })
          end
        end

        get '/list/:field' do
          assets = AssetRequest.list(params[:field])
          return 404 unless assets
          output(assets.collect{|i| i.to_hash() })
        end

        get '/:id' do
          asset = AssetRequest.find(params[:id])
          return 404 unless asset
          output(asset.to_hash())
        end

        delete '/:id' do
          asset = AssetRequest.find(params[:id])
          return 404 unless asset
          asset.destroy()
          200
        end


        %w{
          /?
          /:id
        }.each do |r|
          post r do
            if params[:id]
              asset = AssetRequest.find(params[:id])
              return 404 unless asset
            else
              asset = AssetRequest.new()
            end

            json = MultiJson.load(request.env['rack.input'].read)
            json['user_id'] = @user.id

            note = json.delete('_note')

            asset.from_json(json)

            asset.notes << {
              'created_at' => Time.now.strftime('%Y-%m-%d %H:%M:%S %z'),
              'user_id'    => @user.id,
              'body'       => note
            } unless note.nil?

            asset.save()

            200
          end
        end
      end

      get '/boot/profile/list' do
        rv = Config.get("provisioning.boot.profiles",[])
        rv.compact.to_json
      end

      get '/:id/boot/profile/list' do
        asset = Asset.find(params[:id])
        return 404 unless asset

        rv = Config.get("provisioning.boot.profiles",[])
        rv.compact.to_json
      end

      %w{
        /:id/boot/?
        /:id/boot/set/:profile/?
        /:id/boot/set/:profile/:subprofile/?
      }.each do |r|
        get r do#ne
          asset = Asset.find(params[:id])
          return 404 unless asset

          if params[:profile]
            asset.properties.set('provisioning.boot.profile', params[:profile])
            asset.properties.set('provisioning.boot.subprofile', params[:subprofile]) unless params[:subprofile].nil?
            asset.save()
          end

          status, headers, body = call env.merge({
            'PATH_INFO'    => '/api/ipxe/boot',
            'QUERY_STRING' => "id=#{asset.id}"
          })
          [status, headers, body]
        end
      end

      %w{
        /?
        /:id
      }.each do |r|
        get r do#ne
          content_type 'text/plain'
          if params[:id]
            asset = Asset.find(params[:id])

          elsif (request.env['HTTP_X_RHN_PROVISIONING_MAC_0'] || params[:mac])
            iface = (request.env['HTTP_X_RHN_PROVISIONING_MAC_0'].split(' ').first.strip.chomp rescue 'eth0')
            mac = (request.env['HTTP_X_RHN_PROVISIONING_MAC_0'].split(' ').last rescue param[:mac]).strip.chomp

            asset = Asset.first({
              '$and' => [
                {'properties.network.interfaces.name' => iface},
                {'properties.network.interfaces.mac'  =>
                  {
                    '$regex'   => "^#{mac}$",
                    '$options' => 'i'
                  }
                }
              ]
            }) if mac
          end

          return 404 unless asset

          if params[:status]
            asset.status = params[:status]
            asset.save()
          end

          script_type = asset.properties.get('provisioning.boot.subprofile')
          raise "Property 'provisioning.boot.subprofile' is required" unless script_type.is_a?(String)
          script_type.gsub!(/[\-]/,'/')

          liquid "provisioning/#{script_type.downcase}/#{params[:script] || 'base'}".to_sym, :locals => {
            :device => (asset.to_hash() rescue {}),
            :config => Config.get('provisioning.boot')
          }
        end
      end

      get '/:id/set/:key/:value' do
        asset = Asset.find(params[:id])
        return 404 unless asset

        asset.properties ||= {}
        asset.properties.set("provisioning.#{params[:key]}", params[:value])
        asset.save()

        asset.to_json
      end

      get '/:id/action' do
        asset = Asset.find(params[:id])
        return 404 unless asset


        rv = asset.properties.get('provisioning.action')

        if params[:clear] == 'true'
          if asset.properties['provisioning']
            asset.properties['provisioning'].delete('action')
            asset.save()
          end
        end

        content_type 'text/plain'
        rv
      end

  #   IP Address Management
      namespace '/ipam' do
        get '/:network/:mask/?' do
          require 'net/ping'
          require 'resolv'

          netip = params[:network].split('.').collect{|i| i.to_i.to_s(2).rjust(8,'0') }
          mask = params[:mask].split('.').collect{|i| i.to_i.to_s(2).rjust(8,'0') }
          network = [nil, nil, nil, nil]
          mask.each_index{|i| network[i] = (mask[i].to_i(2) & netip[i].to_i(2)) }
          network = network.reject{|i| i == 0 }.join('.')

          ips = Asset.list('network.interfaces.addresses.ip').to_a
          ips.select!{|i| i =~ Regexp.new("^#{network}") }

          raise ips.inspect

            begin
              Resolv.new.getname ip
            rescue Resolv::ResolvError => e
              if e.message =~ /^no name for/

              end
            end
        end
      end
    end
  end
end
