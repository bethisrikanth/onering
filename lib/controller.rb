require 'sinatra/base'
require 'sinatra/namespace'
require 'sinatra/cross_origin'

require 'errors'
require 'profiler'
require 'stringio'

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
      @_start = Time.now

    # handle query modifiers
      App::Model::Base.query_limit = params[:limit].to_i if params[:limit]
      App::Model::Base.query_offset = params[:offset].to_i if params[:offset]

      if params[:profile] === '1'
        Profiler__.start_profile
      end
    end

    after do
      if params[:profile] === '1'
        Profiler__.stop_profile

        content_type 'text/plain'
        rv = StringIO.new("-- BEGIN PROFILE --\n", "w+")
        Profiler__.print_profile(rv)
        response.body = rv.string()
        response.body << "-- END PROFILE --"
      else
        App::Log.increment("api.requests.status.#{response.status}")
        App::Log.increment("api.requests.all.count")
        App::Log.timing("api.requests.all.time", ( (Time.now.to_f*1000.0).to_i - (@_start.to_f * 1000.0).to_i))
      end
    end

    helpers do
      def allowed_to?(key, *args)
        if @user and not Config.get('global.authentication.disable')
          halt [403, "User #{@user.id} is denied the #{key} capability"] unless @user.has_capability?(key, args)
        end

        true
      end

      def filter_hash(hash, prefix=nil)
        if params[:only]
          hash = [hash] unless hash.is_a?(Array)
          rv = hash.collect do |h|
            h = h.to_hash if h.respond_to?(:to_hash)
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

        when 'xml'
          mime = 'text/xml'
          rv = body.to_xml()

        else
          rv = MultiJson.dump(body)
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
          if ENV['RACK_ENV'] === 'profile'
            require 'rblineprof'

            wrap = Proc.new do
              profile = lineprof(/./) do
                block.bind(self).call()
              end


              content_type 'text/plain'
              rv  = "-- BEGIN DEEP PROFILE --\n"

              profile.each do |file, samples|
                rv += (file+"\n")

                begin
                  File.readlines(file).each_with_index do |line, num|
                    wall, cpu, calls = samples[num+1]
                    if calls && calls > 0
                      rv += ("% 8.1fms + % 8.1fms (% 6d) |% 5d|  %s\n" % [cpu/1000.0, (wall-cpu)/1000.0, calls, (num+1), line.chomp])
                    else
                      rv += ("                                 |% 5d|  %s\n" % [(num+1), line.chomp])
                    end
                  end
                rescue Exception => e
                  rv += "ERROR: #{e.class.name}: #{e.message}\n"
                end

                rv += "\n\n"
              end

              rv += "\n"
              rv += "-- SUMMARY --\n"

              profile.each do |file, data|
                total, child, exclusive = data[0]
                rv += (file+"\n")

                rv += ("  % 10.1fms in this file\n" % [exclusive/1000.0])
                rv += ("  % 10.1fms in this file + children\n" % [total/1000.0])
                rv += ("  % 10.1fms in children\n" % [child/1000.0])
                rv += "\n"
              end
              rv += "-- END DEEP PROFILE --\n"

              response.body = rv
              200
            end
          else
            wrap = block
          end

          Sinatra::Base.send(verb, url, opts, &wrap)
        end
      end
    end
  end
end