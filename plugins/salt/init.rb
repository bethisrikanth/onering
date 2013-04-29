require 'controller'
require 'automation/models/job'

module App
  class Base < Controller
    include Helpers

    namespace '/api/salt' do
      get '/run/:plugin' do
        output(Automation::Job.run_task('salt.run', {
          :parameters => {
            :plugin => params[:plugin],
            :query  => (params[:q] || params[:query]),
            :nodes  => params[:nodes]
          }.compact
        }))
      end

      post '/run/:plugin' do
        output(Automation::Job.run_task('salt.run', {
          :parameters => {
            :plugin    => params[:plugin],
            :arguments => MultiJson.load(request.env['rack.input'].read),
            :query     => (params[:q] || params[:query]),
            :nodes     => params[:nodes]
          }.compact
        }))
      end
    end
  end
end
