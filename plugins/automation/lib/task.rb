require 'hashlib'
require 'rainbow'

module Automation
  module Tasks
    TASKPATH = [
      File.join(File.expand_path(__FILE__), 'tasks'),
      File.join(ENV['PROJECT_ROOT'], 'plugins', '*', 'tasks'),
      '/var/lib/onering/api/tasks'
    ]

    class Base

      def initialize(options={})
        @options = (options || {})
      end

      def opt(key, default=nil)
        return @options.get(key, default)
      end

      def opt!(key, default=nil)
        rv = @options.get(key)
        raise "Parameter '#{key}' is required" if rv.nil?
        return rv
      end

      def abort(message)
        raise TaskAbort.new(message)
      end

      def retry(message)
        raise TaskRetry.new(message)
      end

      def fail(message)
        raise TaskFail.new(message)
      end

      def log(message, severity=:info)
        STDOUT.puts("[TASK] #{message}")
        STDOUT.flush()
      end

      def execute(request, datum=nil)
        @data = datum
        rv = run(request)
        return (rv.nil? ? @data : rv)
      end

    # task stub: implement this to perform the actions for a given task
      def run(request)
        raise "Not Implemented"
      end

      class<<self
        def load_all()
          Automation::Tasks::TASKPATH.each do |path|
            Dir["#{path}/**/*.rb"].each do |f|
              if Automation::Tasks::Base.register(f)
                begin
                  require f
                  puts "Loaded #{f}..."
                rescue LoadError => e
                  STDERR.puts("Unable to load task #{f}: #{e.message}".foreground(:red))
                end
              end
            end
          end
        end

        def register(path)
          name = File.basename(path, '.rb').to_sym
          @_tasks = {} unless @_tasks
          return false if @_tasks[path]

          @_tasks[path] = {
            :name => name,
            :path => path
          }

          return true
        end
      end
    end
  end
end