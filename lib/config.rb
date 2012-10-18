require 'yaml'

module App
  class ConfigKeyError < Exception; end

  class Config
    class<<self
      def load(config)
        config = File.join((config||'.'), 'config', 'config.yaml') if File.directory?(config)
        @_config = YAML.load(File.open(config)) || {}
      end

      def get(path, default=nil)
        root = @_config

        begin
          path.strip.split('/').each do |p|
            root = root[p]
          end

          return root || default
        rescue NoMethodError
          return default
        end
      end

      def get!(path)
        get(path) or raise ConfigKeyError, "config path '#{path}' not found"
      end
    end
  end
end