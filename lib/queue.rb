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
require 'eventmachine'

module App
  class Queue
    class ConnectionFailed < Exception; end

    class<<self
      def setup()
        @_connector = Proc.new do
          begin
            self.connect()
          rescue Exception => e
            STDERR.puts("#{e.class.name}: #{e.message}")
          end
        end

        @_connector.call()

        EM.next_tick do
          EM.add_periodic_timer(App::Config.get('global.queue.recheck_interval', 2)) do
            begin
              @_pool.tubes['default'].peek(:ready)
            rescue Exception => e
              STDERR.puts("Lost connection to work queue, reconnecting...")
              @_connector.call()
            end
          end
        end
      end

      def connect()
        @hosts = [*Config.get('global.queue.host', 'localhost:11300')]
        @_pool = (Beaneater::Pool.new(@hosts) rescue nil)
        @_tubes = {}
      end

      def channel(name=nil)
        @_tubes ||= {}
        @_tubes[name] ||= Channel.new(name, @_pool)
        @_tubes[name]
      end

      def disconnect()
        @_pool.close() if @_pool
      end
    end
  end

  class Channel
    def initialize(name, pool)
      @name = (name || 'default')
      @_pool = pool
      @_tube = (@_pool.tubes[@name] rescue false)
    end

    def push(data)
      return false unless @_tube
      @_tube.put(data.to_msgpack) rescue false
    end

    def <<(data)
      push(data)
    end

    def read()
      rv = []
      while @_tube.peek(:ready) do
        begin
          v = @_tube.reserve()
          rv << v
        ensure
          v.delete()
        end
      end

      return rv
    end

    def subscribe(&block)
      if block_given?
        begin
          raise "Queue not connected" if @_pool.nil?

          @_pool.jobs.register(@name) do |job|
            yield job
          end

          @_pool.jobs.process!

        rescue Beaneater::NotFoundError => e
          retry
        end
      end
    end
  end
end