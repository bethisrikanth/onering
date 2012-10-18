require 'utils'
require 'patches'
require 'json'
require 'model'
require 'controller'

module App
  class Base < Controller
    def initialize
      App::Config.load(PROJECT_ROOT)
      Database::Base.load_all
      super
    end

    mime_type :json, "application/json"
    
    configure do 
      enable  :logging
      #enable  :raise_errors
      disable :raise_errors
      disable :debug
    end

    before do
      content_type 'application/json'
    end

    error do
      {
        :errors => env['sinatra.error'].message
      }.to_json
    end
  end
end
