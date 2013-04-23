require 'hashlib'

module Automation
  class Task
    TASKPATH = [
      File.join(File.expand_path(__FILE__), 'tasks'),
      File.join(ENV['PROJECT_ROOT'], 'lib', 'tasks'),
      '/var/lib/onering/api/tasks'
    ]

    def initialize(options={})
      @options = options
      @data = nil
    end

    def opt(key, default=nil)
      return @options.get(key, default)
    end

    def opt!(key, default=nil)
      rv = @options.get(key)
      raise "Parameter '#{key}' is required" if rv.nil?
      return rv
    end

    def data=(datum)
      @data = datum
    end

    def execute(request)
      rv = run(request)
      return (rv.nil? ? @data : rv)
    end


    def error(message)
      STDERR.log(message.foreground(:red))
    end

  # task stub: implement this to perform the actions for a given task
    def run(request)
      raise "Not Implemented"
    end

    class<<self
      def load_all()
        Automation::Task::TASKPATH.each do |path|
          Dir["#{path}/**/*.rb"].each do |f|
            puts "Loading #{f}..."
            Automation::Task.register(f)
            require f
          end
        end
      end

      def register(path)
        name = File.basename(path, '.rb').to_sym
        @_tasks = {} unless @_tasks
        @_tasks[name] ||= {
          :name => name,
          :path => path
        }
      end
    end
  end
end

Automation::Task.load_all()