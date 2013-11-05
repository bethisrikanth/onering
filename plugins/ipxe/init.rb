require 'controller'
require 'assets/models/asset'

module App
  class Base < Controller
    namespace '/api/ipxe' do
      get '/boot' do
        content_type 'text/plain'

        if params[:id]
          device = Asset.find(params[:id])
        elsif params[:mac] and not params[:mac].empty?
        # TODO: order by collected_at DESC
          device = Asset.urlquery("mac|network.interfaces.mac/#{params[:mac]}").to_a.first
        elsif params[:uuid] and not params[:uuid].empty?
        # TODO: order by collected_at DESC
          device = Asset.urlquery("uuid/#{params[:uuid]}").to_a.first
        end

        liquid "ipxe/boot".to_sym, :locals => {
          :device => (device.to_hash() rescue nil),
          :config => Config.get('provisioning.boot')
        }
      end
    end
  end
end
