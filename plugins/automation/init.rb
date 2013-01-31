require 'controller'
require 'assets/models/device'
require 'automation/models/automation_request'
require 'automation/models/automation_result'
require 'automation/lib/helpers'

module App
  class Base < Controller
    include Helpers

    namespace '/api/automation' do
      get '/find/*/run/*' do
        qsq = (params[:q] || params[:query] || '')
        q = (!params[:splat] || params[:splat].empty? ? qsq : params[:splat].first.split('/').join('/')+(qsq ? '/'+qsq : ''))
        devices = Device.urlsearch(q).limit(params[:limit] || 1000)
        return 404 unless devices

        commands = params[:splat].last
        arguments = (params[:args] || '').split('|')

        rv = proxy_command_to_sites(devices, commands, arguments)

        rv.to_json
      end
    end
  end
end
