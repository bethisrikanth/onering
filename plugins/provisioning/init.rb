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
        /boot/?
        /boot/:id
      }.each do |r|
        get r do
          content_type 'text/plain'
          if params[:id]
            device = Device.find(params[:id])
            return 404 unless device

          elsif request['X-RHN-Provisioning-MAC-0'] || params[:mac]
            mac = (request['X-RHN-Provisioning-MAC-0'].split(' ').last rescue param[:mac])
            device = Device.first({
              'properties.mac' => mac
            }) if mac          
            return 404 unless device

          end

          liquid 'boot/kickstart/base'.to_sym, :locals => {
            :device => (device.to_h rescue {}),
            :config => Config.get('provisioning/boot')
          }
        end
      end
    end
  end
end
