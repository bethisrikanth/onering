require 'rubygems'
require 'utils'
require 'patches'
require 'model'
require 'controller'
require 'sinatra/assetpack'

module App
  class Base < Controller

    def initialize
      App::Config.load(ENV['PROJECT_ROOT'])
      Database::Base.load_all
      super
    end

    mime_type :json, "application/json"

    configure do
      set :root, ENV['PROJECT_ROOT']
      set :environment, ENV['RACK_ENV'].to_sym if ENV['RACK_ENV']
      set :protection, :except => :json_csrf

      enable  :logging
      #enable  :raise_errors
      disable :raise_errors
      disable :debug

      register Sinatra::AssetPack
      use MongoMapper::Middleware::IdentityMap

      assets {
        serve '/js',   :from => 'public/js'
        serve '/css/', :from => 'public/css'
        serve '/img',  :from => 'public/img'

        js :app, '/js/app.js', [
          "/js/vendor/jquery-1.8.2.min.js",
          "/js/vendor/jquery-ui.js",
          "/js/vendor/angular.min.js",
          "/js/vendor/bootstrap.min.js",
          "/js/vendor/moment.min.js",
          "/js/vendor/angular-resource.min.js",
          "/js/services.js",
          "/js/directives.js",
          "/js/filters.js",
          "/js/main.js",
          "/js/controllers.js",
        ]

        css :app, '/css/app.css', [
          "/css/bootstrap.min.css",
          "/css/bootstrap-responsive.min.css",
          "/css/main.css"
        ]
      }

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
