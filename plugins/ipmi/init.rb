require 'controller'
require 'ipmi/lib/asset_extensions'

module App
  class Base < Controller
    namespace '/api/devices' do
      get '/:id/ipmi/:command/?*' do
        node = Asset.find(params[:id])
        return 404 unless node

        if params[:splat].first.empty?
          args = []
        else
          args = params[:splat].first.split('/').collect{|i|
            i.autotype()
          }
        end

        output({
          :id      => node.id,
          :bmc     => {
            :ip => node.get(:ipmi_ip),
            :netmask => node.get(:ipmi_netmask),
            :gateway => node.get(:ipmi_gateway),
            :mac => node.get(:ipmi_macaddress)
          },
          :command => params[:command],
          :arguments => args,
          :result  => node.ipmi_command(params[:command], {
            :arguments => args
          })
        })
      end
    end
  end
end
