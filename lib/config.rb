require 'yaml'
require 'hashlib'
require 'pp'

module App
  class ConfigKeyError < Exception; end

  class Config
    class<<self
      def load(config)
        config = File.join((config||'.'), 'config', 'config.yaml') if File.directory?(config)
        @_config = YAML.load(File.open(config)) || {}

        Dir["config/conf.d/**/*.yaml"].sort.each do |conf|
          data = (YAML.load(File.open(conf)) rescue nil)

        # dont bother with empty, erroneous, or pointless configs
          if not data.nil? and not data === false and not (data.respond_to?(:empty?) and data.empty?)
            confpath = conf.split('/')[2..-1]
            confpath = (confpath[0..-2]+[File.basename(confpath[-1], '.yaml')]).join('.')

            apply(confpath, data)
          end
        end

        @_config
      end

      def apply(path, value)
        current = @_config.get(path)

      # this is necessary because hashlib seems to be replacing the key entirely
      # if the value is a hash
      #
        if current.is_a?(Hash)
          @_config.set(path, current.deeper_merge!(value))
        else
          @_config.set(path, value)
        end

        self
      end

      def register(id, path, data)
        @_externalconfig ||= {}
        @_externalconfig[id] = {
          :path => path,
          :data => data
        }
      end

      def unregister(id)
        if @_externalconfig.is_a?(Hash)
          @_externalconfig.delete(id)
        end
      end

      def registrations()
        @_externalconfig
      end

      def get(path, default=nil)
        to_hash().get(path, default)
      end

      def get!(path)
        to_hash().get(path) or raise ConfigKeyError, "config path '#{path}' not found"
      end

      def set(path, value)
        @_config.set(path, value)
      end

      def to_hash()
        @_externalconfig ||= {}

        rv = @_config

        @_externalconfig.each do |id, config|
          merge_config = {}
          merge_config.set(config[:path], config[:data])

          rv = rv.deep_merge(merge_config)
        end

        return rv
      end
    end
  end
end