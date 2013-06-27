require 'config'
require 'socket'
require 'msgpack'
require 'statsd'

module App
  class Log
    class<<self
      def setup()
        @_prefix = Config.get('global.metrics.prefix', '')

        unless @_prefix.empty?
          @_prefix.scan(/\$\([^\)]+\)/).each do |pattern|
            pattern.strip!
            @_prefix = @_prefix.sub(pattern, (IO.popen(pattern[2..-2] + " 2> /dev/null").read.lines.first.chomp))
          end
        end

        @_statsd = Statsd.new(Config.get('global.metrics.host', '127.0.0.1'), Config.get('global.metrics.port', 8125))
        @_statsd.namespace = @_prefix.gsub(/\.$/,'')
      end

    # default value of one makes events very simple to log
      def increment(metric)
        @_statsd.increment(metric)
      end

      def decrement(metric)
        @_statsd.decrement(metric)
      end

      def gauge(metric, value)
        @_statsd.gauge(metric, value)
      end

      def timing(metric, time_ms)
        @_statsd.timing(metric, time_ms)
      end
    end
  end
end