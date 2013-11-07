require 'controller'
require 'ipmi/lib/asset_extensions'

module App
  class Base < Controller
    namespace '/api/devices' do
      get '/:id/ipmi/:command' do
        node = Asset.find(params[:id])
        return 404 unless node

        output({
          :id      => node.id,
          :bmc     => {
            :ip => node.get(:ipmi_ip),
            :netmask => node.get(:ipmi_netmask),
            :gateway => node.get(:ipmi_gateway),
            :mac => node.get(:ipmi_macaddress)
          },
          :command => params[:command],
          :result  => node.ipmi_command(params[:command])
        })
      end
    end
  end
end
