require 'liquid_patches'
require 'controller'
require 'assets/models/device'
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
      def get_macs(device)
        macs = []

        device.properties.get('network.interfaces').each do |iface|
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
          get r do
            if params[:splat].nil?
              assets = AssetRequest.all()
            else
              k,v = params[:splat].first.split('/')
              assets = AssetRequest.where({
                k => v
              })
            end

            return 404 unless assets
            output(assets.collect{|i| i.to_h })
          end
        end

        get '/list/:field' do
          assets = AssetRequest.list(params[:field])
          return 404 unless assets
          output(assets.collect{|i| i.to_h })
        end

        get '/:id' do
          asset = AssetRequest.find(params[:id])
          return 404 unless asset
          output(asset.to_h)
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
            note = json.delete('notes')
            asset.from_json(json)
            asset.notes << note
            asset.safe_save()

            200
          end
        end
      end


      get '/:id/boot/profile' do
        device = Device.find(params[:id])
        return 404 unless device

        rv = []
        pxed = Config.get("provisioning.pxed.#{device.properties['site'].downcase}.url")
        macs = get_macs(device)

        macs.each do |mac|
          response = Net::HTTP.get_response(URI("#{pxed}/devices/01-#{mac[:mac].downcase.gsub(':', '-')}/profile"))
          rv << (MultiJson.load(response.body).merge(mac) rescue nil)
        end

        rv.compact.to_json
      end

      get '/:id/boot/profile/list' do
        device = Device.find(params[:id])
        return 404 unless device

        pxed = Config.get("provisioning.pxed.#{device.properties['site'].downcase}.url")
        response = Net::HTTP.get_response(URI("#{pxed}/profiles/list"))
        rv = (MultiJson.load(response.body) rescue [])

        rv.compact.to_json
      end

      %w{
        /:id/boot/?
        /:id/boot/set/:profile/?
      }.each do |r|
        get r do
          device = Device.find(params[:id])
          return 404 unless device

          if device.properties['site']
            pxed = Config.get("provisioning.pxed.#{device.properties['site'].downcase}.url")
            uses_default = true
            macs = get_macs(device)

            rv  = "# ============================================================================= \n"
            rv += "# pxed server at #{pxed}, site #{device.properties['site'].upcase}\n"
            rv += "# ============================================================================= \n"
            rv += "\n\n"

            macs.each do |mac|
              rv += "# ----------------------------------------------------------------------------- \n"
              rv += "# PXE configuration for device #{mac[:interface]} (#{mac[:mac]})\n"
              rv += "# ----------------------------------------------------------------------------- \n"

              if params[:profile]
                response = Net::HTTP.get_response(URI("#{pxed}/devices/01-#{mac[:mac].downcase.gsub(':', '-')}/link/#{params[:profile]}"))
              else
                response = Net::HTTP.get_response(URI("#{pxed}/devices/01-#{mac[:mac].downcase.gsub(':', '-')}"))
              end

              if response.code.to_i < 400
                uses_default = false
                rv += response.body
              end

              rv += "\n\n"
            end

            if uses_default
              rv += "# Default PXE configuration\n"
              rv += "#\n"
              rv += (Net::HTTP.get(URI("#{pxed}/devices/default")) rescue '')
            end

            content_type 'text/plain'
            rv
          else
            raise "Cannot provision device #{device.id} without specifying a site"
          end
        end
      end

      %w{
        /?
        /:id
      }.each do |r|
        get r do
          content_type 'text/plain'
          if params[:id]
            device = Device.find(params[:id])

          elsif (request.env['HTTP_X_RHN_PROVISIONING_MAC_0'] || params[:mac])
            iface = (request.env['HTTP_X_RHN_PROVISIONING_MAC_0'].split(' ').first.strip.chomp rescue 'eth0')
            mac = (request.env['HTTP_X_RHN_PROVISIONING_MAC_0'].split(' ').last rescue param[:mac]).strip.chomp

            device = Device.first({
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

          return 404 unless device

          if params[:status]
            device.status = params[:status]
            device.safe_save
          end

          script_type = device.properties.get('provisioning.family')

          raise "Property 'provisioning.family' is required" unless script_type

          liquid "provisioning/#{script_type.downcase}/base".to_sym, :locals => {
            :device => (device.to_h rescue {}),
            :config => Config.get('provisioning.boot')
          }
        end
      end

      get '/:id/set/:key/:value' do
        device = Device.find(params[:id])
        return 404 unless device

        device.properties ||= {}
        device.properties.set("provisioning.#{params[:key]}", params[:value])
        device.safe_save

        device.to_json
      end

      get '/:id/action' do
        device = Device.find(params[:id])
        return 404 unless device


        rv = device.properties.get('provisioning.action')

        if params[:clear] == 'true'
          if device.properties['provisioning']
            device.properties['provisioning'].delete('action')
            device.safe_save
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

          ips = Device.list('network.interfaces.addresses.ip').to_a
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
