require 'yaml'
require 'hashlib'

module App
  class ConfigKeyError < Exception; end

  class Config
    class<<self
      def load(config)
        config = File.join((config||'.'), 'config', 'config.yaml') if File.directory?(config)
        @_config = YAML.load(File.open(config)) || {}
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