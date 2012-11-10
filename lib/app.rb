require 'rubygems'
require 'utils'
require 'patches'
require 'json'
require 'model'
require 'controller'

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
      set :environment, ENV['RACK_ENV']

      enable  :logging
      #enable  :raise_errors
      disable :raise_errors
      disable :debug
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
