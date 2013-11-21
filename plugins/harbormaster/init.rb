require 'controller'
require 'assets/models/asset'

module App
  class Base < Controller
    DEFAULT_MESOS_API_PORT=5050
    DEFAULT_MESOS_API_STATEFILE='/master/state.json'

    namespace '/api/devices' do
      get '/:id/mesos' do
        asset = Asset.find(params[:id])
        return 404 unless asset
        #return 404 unless asset.get('network.sockets.listening.port', []).include?((params[:port] || DEFAULT_MESOS_API_PORT).to_i)

        qs = request.env['rack.request.query_hash'].collect{|k,v| "#{k}=#{v}" }.join('&')
        redirect ["http://#{[*asset.get(:ip,[])].first}:#{(params[:port] || DEFAULT_MESOS_API_PORT).to_i}#{DEFAULT_MESOS_API_STATEFILE}", qs].compact.join('?')
      end
    end

    namespace '/api/harbormaster' do
      namespace '/mesos' do
        get '/clusters' do
          rv = {}

          Asset.urlquery("name/mesos/network.sockets.listening.port/2181").each do |asset|
            rv[asset.get(:site)] ||= {}
            rv[asset.get(:site)][asset.id] = asset.to_hash()
          end

          output(rv)
        end
      end
    end
  end
end
