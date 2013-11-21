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

        begin
          response = Net::HTTP.get_response(URI(["http://#{[*asset.get(:ip,[])].first}:#{(params[:port] || DEFAULT_MESOS_API_PORT).to_i}#{DEFAULT_MESOS_API_STATEFILE}", qs].compact.join('?')))
          rv = MultiJson.load(response.body)

          output(rv)
        rescue
          halt 502
        end
      end
    end

    namespace '/api/harbormaster' do
      namespace '/mesos' do
        get '/clusters' do
          rv = {}

          Asset.urlquery("mesos.masters.pid").each do |asset|
            asset.get('mesos.masters', []).each do |master|
              rv[asset.get(:site)] ||= {}
              rv[asset.get(:site)][master.get('options.cluster', asset.id)] = master.merge({
                :id   => asset.id,
                :site => asset.get(:site)
              })
            end
          end

          output(rv)
        end
      end
    end
  end
end
