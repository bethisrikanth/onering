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

      enable  :logging
      #enable  :raise_errors
      disable :raise_errors
      disable :debug

      register Sinatra::AssetPack

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

    before do
      cache_control :private, :must_revalidate, :max_age => 60
    end

    error do
      content_type 'application/json'

      {
        :errors => {
          :type => env['sinatra.error'].class.to_s,
          :message => env['sinatra.error'].message
        }
      }.to_json
    end
  end
end
