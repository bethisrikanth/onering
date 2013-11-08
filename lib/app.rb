ENV['PROJECT_ROOT'] = File.dirname(File.dirname(File.expand_path(__FILE__)))
$: << File.join(ENV['PROJECT_ROOT'], 'lib')
$: << File.join(ENV['PROJECT_ROOT'], 'plugins')

require 'rubygems'
require 'oj'
require 'onering'

Onering::Logger.setup({
  :destination => 'STDERR',
  :threshold   => (ENV['LOGLEVEL'] || 'INFO').downcase.to_sym
})


require 'patches'
require 'config'
require 'log'
require 'queue'
require 'utils'
require 'model'
require 'msgpack'
require 'controller'
require 'eventmachine'
require 'multi_json'
require 'liquid_patches'
require 'pp'

# initialize model logging
Tensor::Model.logger = Onering::Logger.logger()

# initialize database settings
App::Model::Elasticsearch.configure(App::Config.get('database.elasticsearch', {}))

# require plugins
Dir[File.join(ENV['PROJECT_ROOT'],'plugins', '*')].each do |p|
  name = File.basename(p)

  begin
    require "#{name}/init"
  rescue LoadError
    next
  end
end


module App
  class Base < Controller
    def initialize
      App::Log.setup()
      App::Log.increment("api.process.started")
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
      set     :views, File.join(ENV['PROJECT_ROOT'], 'config', 'templates')

      ::Liquid::Template.file_system = ::Liquid::LocalFileSystem.new(settings.views)
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
