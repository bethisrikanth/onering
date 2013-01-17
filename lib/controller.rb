require 'sinatra/base'
require 'sinatra/namespace'
require 'sinatra/cross_origin'

module App
  class Controller < Sinatra::Base
    register Sinatra::Namespace
    register Sinatra::CrossOrigin

    configure do
      set :allow_origin, :any
      set :allow_methods, [:get, :post, :options]
      set :allow_credentials, true
      enable :cross_origin
    end

    before do
      headers 'Access-Control-Allow-Headers' => 'origin, x-requested-with, accept'
    end

    helpers do
      def output(body, status=200, mime='application/json')
        rv = nil

        case params[:format]
        when 'txt'
          mime = 'text/plain'
          rv = format_text(body)

        when 'yaml'
          mime = 'text/yaml'
          rv = YAML.dump(body)

        else
          rv = body.to_json
        end

        [status, { 'Content-Type' => mime }, rv]
      end

      def format_text(body)
        if body.is_a?(Array)
          body.join("\n")
        elsif body.is_a?(Hash)
          body.coalesce.to_a.collect{|i|
            key = i.first
            val = (i.last.is_a?(Array) ? i.last.join(",") : i.last)

            "#{key}: #{val}"

          }.join("\n")
        else
          body.to_s
        end
      end
    end

    class<<self
      def get(url, opts={}, &block)
        any(url, ['get', 'options'], opts, &block)
      end

      def post(url, opts={}, &block)
        any(url, ['post'], opts, &block)
      end

      def put(url, opts={}, &block)
        any(url, ['put'], opts, &block)
      end

      def delete(url, opts={}, &block)
        any(url, ['delete'], opts, &block)
      end

      def options(url, opts={}, &block)
        any(url, ['options'], opts, &block)
      end

      def head(url, opts={}, &block)
        any(url, ['head'], opts, &block)
      end

      def patch(url, opts={}, &block)
        any(url, ['patch'], opts, &block)
      end

    # TODO: url can be prefixed with a root (see Grape::API resource-do)
      def any(url, verbs=%w(get post put delete options head patch), opts={}, &block)
        verbs.each do |verb|
          Sinatra::Base.send(verb, url, opts, &block)
        end
      end
    end
  end
end