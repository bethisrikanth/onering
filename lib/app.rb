$: << File.join(ENV['PROJECT_ROOT'], 'lib')
$: << File.join(ENV['PROJECT_ROOT'], 'plugins')

require 'rubygems'
require 'active_support'
require 'mongo_patches'
require 'config'
require 'db'
require 'queue'
require 'utils'
require 'patches'
require 'model'
require 'controller'
require 'eventmachine'

# require plugins
Dir[File.join(ENV['PROJECT_ROOT'],'plugins', '*')].each do |p|
  name = File.basename(p)
  require "#{name}/init"
end


module App
  class Base < Controller

    def initialize
      App::Config.load(ENV['PROJECT_ROOT'])
      Database::Base.load_all()
      Queue.setup()
      super
    end


    configure do
      mime_type :json, 'application/json'

      set :root, ENV['PROJECT_ROOT']
      set :environment, ENV['RACK_ENV'].to_sym if ENV['RACK_ENV']
      set :protection, :except => :json_csrf

      enable  :logging
      #enable  :raise_errors
      disable :raise_errors
      disable :debug
    end

    error do
      content_type 'application/json'

      {
        :error => {
          :type => env['sinatra.error'].class.to_s,
          :message => env['sinatra.error'].message,
          :backtrace => env['sinatra.error'].backtrace,
          :severity  => params[:severity]
        }
      }.to_json
    end

    error 400 do
      content_type 'application/json'
      message = (response.body.empty? ? "Invalid or malformed request for resource #{request.path}" : [*response.body].join(','))

      {
        :error => {
          :type => "Bad Request",
          :message => message,
          :severity  => params[:severity]
        }
      }.to_json
    end

    error 401 do
      content_type 'application/json'
      message = (response.body.empty? ? "Invalid credentials for accessing #{request.path}" : [*response.body].join(','))

      {
        :error => {
          :type => "Unauthorized",
          :message => message,
          :severity  => params[:severity]
        }
      }.to_json
    end

    error 403 do
      content_type 'application/json'
      message = (response.body.empty? ? "User #{@user.id || 'anonymous'} is not authorized to access #{request.path}" : [*response.body].join(','))

      {
        :error => {
          :type => "Forbidden",
          :message => message,
          :severity  => params[:severity]
        }
      }.to_json
    end

    error 404 do
      content_type 'application/json'
      message = (response.body.empty? ? "Resource #{request.path} does not exist" : [*response.body].join(','))

      {
        :error => {
          :type => "Not Found",
          :message => message,
          :severity  => params[:severity]
        }
      }.to_json
    end
  end
end
