require 'liquid_patches'
require 'controller'
require 'assets/models/device'

module App
  class Base < Controller
    configure do
      set :views, File.join(File.dirname(__FILE__), 'views')
      ::Liquid::Template.file_system = ::Liquid::LocalFileSystem.new(settings.views)
    end

    namespace '/api/provision' do
      %w{
        /?
        /:id
      }.each do |r|
        get r do
          content_type 'text/plain'
          if params[:id]
            device = Device.find(params[:id])

          elsif request['X-RHN-Provisioning-MAC-0'] || params[:mac]
            mac = (request['X-RHN-Provisioning-MAC-0'].split(' ').last rescue param[:mac])
            device = Device.first({
              '$and' => [
                {'properties.network.interfaces.name' => 'eth0'},
                {'properties.network.interfaces.mac'  =>  mac}
              ]
            }) if mac
          end

          return 404 unless device

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
    end
  end
end
