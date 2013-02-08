require 'sinatra/base'
require 'sinatra/namespace'
require 'sinatra/cross_origin'

require 'errors'

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
      def allowed_to?(key, *args)
        if @user and not Config.get('global.authentication.disable')
          raise Errors::HttpForbidden.new("User #{@user.id} is denied the #{key} capability") unless @user.capability?(key, args)
        end

        true
      end

      def filter_hash(hash, prefix=nil)
        if params[:only]
          hash = [hash] unless hash.is_a?(Array)
          rv = hash.collect do |h|
            h = h.to_h if h.respond_to?(:to_h)
            _rv = {}

          # prepend properties to all :only fields, as this is implied
            only = params[:only].split(/[\,\|]/).collect{|i| i = "#{prefix ? prefix.to_s+'.' : ''}#{i}" }

          # knock the prefixed key out of the result object to be selectively filled in below
            _rv = h.reject{|k,v| k.to_s == prefix.to_s } if prefix

          # flatten out the hash tree to make key searches less recursive
            h.coalesce(nil,nil,'.').each do |k,v|
            # only add this value to the output if its key path exists in the requested set of keys
              _rv.set(k,v) unless only.collect{|i| (k =~ Regexp.new("^#{i}(?![a-z])") ? true : nil) }.compact.empty?
            end

            _rv
          end

          if hash.is_a?(Array)
            return rv
          else
            return rv.first
          end
        end

        return hash
      end

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