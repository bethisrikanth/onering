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

            @_config.rset(confpath, data)
          end
        end

        @_config
      end

      def get(path, default=nil)
        @_config.get(path, default)
      end

      def get!(path)
        get(path) or raise ConfigKeyError, "config path '#{path}' not found"
      end
    end
  end
end