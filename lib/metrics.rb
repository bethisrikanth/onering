# Copyright 2012 Outbrain, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'config'
require 'socket'
require 'statsd'

module App
  class Metrics
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