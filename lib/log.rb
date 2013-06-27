require 'config'
require 'socket'

module App
  class Log
    class<<self
      def setup()
        _connect_metrics_logger()

      # setup watchdog for remote metrics
        EM.next_tick do
          EM.add_periodic_timer(App::Config.get('global.metrics.recheck_interval', 30).to_i) do
            _connect_metrics_logger()
          end
        end
      end

    # default value of one makes events very simple to log
      def observe(metric, value=1, time=Time.now)
        begin
          @_metrics.puts("#{@_prefix}#{metric} #{value.to_f} #{time.to_i}")
          @_metrics.flush()
        rescue
          return false
        end
      end


      def metrics_logger_connected?()
        return false if @_metrics.nil?
        return true
      end

      def setup_metrics_logger()
        host = App::Config.get('global.metrics.host', 'localhost')
        port = App::Config.get('global.metrics.port', 2003).to_i

        @_metrics = TCPSocket.new(host, port)
        @_prefix = Config.get('global.metrics.prefix', '')

        STDERR.puts("Remote metrics receiver connected to #{host}:#{port}")

        unless @_prefix.empty?
          @_prefix.scan(/\$\([^\)]+\)/).each do |pattern|
            pattern.strip!
            @_prefix = @_prefix.sub(pattern, (IO.popen(pattern[2..-2] + " 2> /dev/null").read.lines.first.chomp rescue ''))
          end
        end
      end

      private
        def _connect_metrics_logger()
          begin
            if not metrics_logger_connected?
              setup_metrics_logger()
            end
          rescue Exception => e
            STDERR.puts("Lost connection to remote metrics receiver")
            STDERR.puts("#{e.class.name}: #{e.message}")
          end
        end
    end
  end
end