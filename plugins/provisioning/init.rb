require 'liquid_patches'
require 'controller'
require 'assets/models/device'
require 'uri'
require 'net/http'

module App
  class Base < Controller
    configure do
      set :views, File.join(File.dirname(__FILE__), 'views')
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
            macs = []

            device.properties.get('network.interfaces').each do |iface|
              if ['eth0', 'eth1'].include?(iface['name'])
                macs << "01-#{iface['mac'].downcase.gsub(':', '-')}" if iface['mac']
              end
            end

            rv = ''

            macs.compact.uniq.each do |mac|
              rv += "# PXE configuration for device #{mac}\n"

              if params[:profile]
                rv += (Net::HTTP.get(URI("http://pxe.#{device.properties['site'].downcase}.outbrain.com:9521/devices/#{mac}/link/#{params[:profile]}")) rescue '')
              else
                rv += (Net::HTTP.get(URI("http://pxe.#{device.properties['site'].downcase}.outbrain.com:9521/devices/#{mac}")) rescue '')
              end

              rv += "\n"
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

          liquid 'boot/kickstart/base'.to_sym, :locals => {
            :device => (device.to_h rescue {}),
            :config => Config.get('provisioning/boot')
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
          device.properties['provisioning'].delete('action')
          device.safe_save
        end

        rv
      end
    end
  end
end
