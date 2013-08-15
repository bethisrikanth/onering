require 'controller'
require 'salt/lib/salt'
require 'automation/models/job'
require 'assets/models/asset'

module App
  class Base < Controller
    include Helpers

    namespace '/api/salt' do
      namespace '/devices' do
        get '/:id/ping' do
          device = Asset.find(params[:id])
          return 404 unless device

          salt = Salt::API.new(Config.get!("automation.saltrest.#{device.properties['site'].downcase}.url"))
          code, rv = salt.run('test.ping', nil, {
            :nodes => [device.id],
            :async => false
          })

          if code < 400 and not rv.nil?
            if rv.get([device.id, "test.ping"], false) === true
              return 200
            else
              return 503
            end
          else
            raise "Error occurred running command.  Got #{code} response from #{salt.uri}"
          end
        end
      end

      get '/run/:plugin' do
        output(Automation::Job.run_task('salt.run', {
          :parameters => (request.env['rack.request.query_hash'].merge({
            :plugin => params[:plugin],
            :query  => (params[:q] || params[:query]),
            :nodes  => params[:nodes].split('|')
          })).compact
        }))
      end

      post '/run/:plugin' do
        output(Automation::Job.run_task('salt.run', {
          :parameters => {
            :plugin    => params[:plugin],
            :arguments => MultiJson.load(request.env['rack.input'].read),
            :query     => (params[:q] || params[:query]),
            :nodes     => params[:nodes].split('|')
          }.compact
        }))
      end
    end
  end
end
