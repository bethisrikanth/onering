require 'sinatra/base'
require 'sinatra/namespace'

module App
  class Controller < Sinatra::Base
    register Sinatra::Namespace

    before do
      headers 'Access-Control-Allow-Origin' => '*'
    end

    class<<self
      def get(url, opts={}, &block)
        any(url, ['get'], opts, &block)
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