require 'sinatra/base'
require 'utils'
require 'patches'
require 'json'
require 'model'
require 'controller'

module App
  class Base < Controller
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

  class Jsonify < Sinatra::Base
    def initialize(app)
      @app = app
    end

    def call(env)
      @status, @headers, @body = @app.call(env)

      if @status.to_i < 500
        if @body.is_a?(Hash) or
          @body.is_a?(Array) or
          @headers['Content-Type'] == 'application/json'

          @body = @body.to_json
          
          @headers['Content-Length'] = @body.to_s.bytesize.to_s
        end
      end

      [@status, @headers, @body]
    end
  end
end
