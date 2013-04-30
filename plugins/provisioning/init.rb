require 'liquid_patches'
require 'controller'
require 'assets/models/device'
require 'uri'
require 'net/http'

module App
  class Base < Controller
    configure do
      set :views, File.join(ENV['PROJECT_ROOT'], 'config', 'templates')
      ::Liquid::Template.file_system = ::Liquid::LocalFileSystem.new(settings.views)
    end

    namespace '/api/provision' do
      %w{
        /:id/boot/?
        /:id/boot/:profile/?
      }.each do |r|
        get r do
          device = Device.find(params[:id])
          return 404 unless device

          if device.properties['site']
            pxed = Config.get("provisioning.pxed.#{device.properties['site'].downcase}.url")
            uses_default = true
            macs = []

            device.properties.get('network.interfaces').each do |iface|
              if ['eth0', 'eth1'].include?(iface['name'])
                macs << "01-#{iface['mac'].downcase.gsub(':', '-')}" if iface['mac']
              end
            end

            rv  = "# ============================================================================= \n"
            rv += "# pxed server at #{pxed}, site #{device.properties['site'].upcase}\n"
            rv += "# ============================================================================= \n"
            rv += "#\n"

            macs.compact.uniq.each do |mac|
              rv += "# PXE configuration for device #{mac}\n"
              rv += "#\n"

              if params[:profile]
                response = Net::HTTP.get_response(URI("#{pxed}/devices/#{mac}/link/#{params[:profile]}"))
              else
                response = Net::HTTP.get_response(URI("#{pxed}/devices/#{mac}"))
              end

              if response.code.to_i < 400
                uses_default = false
                rv += response.body
              end

              rv += "#\n"
            end

            if uses_default
              rv += "# Default PXE configuration\n"
              rv += "#\n"
              rv += (Net::HTTP.get(URI("#{pxed}/devices/default")) rescue '')
            end

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

          liquid "automation/#{script_type.downcase}/base", :locals => {
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
