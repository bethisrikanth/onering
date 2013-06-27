require 'config'
require 'socket'
require 'msgpack'

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
      end

    # default value of one makes events very simple to log
      def observe(metric, value=1, time=Time.now)
        # begin
          payload = {
            'metric'=> "#{@_prefix}#{metric}",
            'value' => value.to_f,
            'time'  => time.to_i
          }

          App::Queue.channel(App::Config.get('global.metrics.queue', 'onering-metrics')) << payload
        # rescue
        #   return false
        # end
      end
    end
  end
end