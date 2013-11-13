require 'resque'
require 'resque/errors'
require 'onering'
require 'metrics'
require 'automation/lib/util'

module Automation
  module Tasks
    class JobTermination  < Exception; end
    class TaskTermination < Exception; end

    class JobAbort  < JobTermination; end
    class JobRetry  < JobTermination; end
    class JobFail   < JobTermination; end
    class TaskAbort < TaskTermination; end
    class TaskRetry < TaskTermination; end
    class TaskFail  < TaskTermination; end
    class TaskJump  < TaskTermination; end

    class Task
      extend Util

      TASKPATH = [
        File.join(ENV['PROJECT_ROOT'], 'plugins', '*', 'tasks')
      ]

      def self.load_all()
        TASKPATH.each do |path|
          Dir["#{path}/**/*.rb"].each do |f|
            begin
              Onering::Logger.debug("Loading Resque task #{f}", "Automation::Tasks::Task")
              require f
            rescue LoadError => e
              Onering::Logger.error("Unable to load task #{f}: #{e.message}", "Automation::Tasks::Task")
              next
            end
          end
        end
      end

      def self.run_task(priority, name, *args)
        task = as_task(name)

        unless task.nil?
          return Resque.enqueue_to(priority, task, *args)
        else
          Onering::Logger.error("Cannot locate task #{name}", "Automation::Tasks::Task")
        end

        return false
      end

      def self.run(name, *args)
        run_task(:normal, name, *args)
      end

      def self.run_critical(name, *args)
        run_task(:critical, name, *args)
      end

      def self.run_high(name, *args)
        run_task(:high, name, *args)
      end

      def self.run_low(name, *args)
        run_task(:low, name, *args)
      end

      def self.as_task(name)
        begin
          return (['Automation', 'Tasks'] + name.split(/[\.\/]/).map(&:camelize)).join('::').constantize()
        rescue NameError => e
          Onering::Logger.error("Cannot resolve task name #{name}, #{e.message}", "Automation::Tasks::Task")
          return nil
        end
      end

      def self.to_task_name(joiner='/')
        self.name.split('::')[2..-1].map(&:underscore).join(joiner)
      end

      def self.before_perform_aaa_log_metrics(*args)
        @_start = Time.now
        @_task = to_task_name('-')
        Onering::Logger.info("Starting task at #{@_start.to_s}", to_task_name())
        App::Metrics.increment("worker.tasks.#{@_task}.started")
        App::Metrics.increment("worker.tasks.all.started")
      end

      def self.after_perform_aaa_log_metrics(*args)
        @_end = Time.now
        time = (@_end - @_start)
        Onering::Logger.info("Task completed at #{@_end.to_s} (took: #{"%.6f" % time.to_f} seconds)", to_task_name())
        App::Metrics.increment("worker.tasks.all.completed")
        App::Metrics.timing("worker.tasks.all.time", (time.to_f * 1000.0).to_i)

        App::Metrics.increment("worker.tasks.#{@_task}.completed")
        App::Metrics.timing("worker.tasks.#{@_task}.time", (time.to_f * 1000.0).to_i)
      end

      def self.on_failure(e, *args)
        error_class = case e.class.name
        when /^Automation::Tasks::/
          e.class.name.split('::').last.to_sym
        else
          e.class.name
        end

        source = [to_task_name(), error_class.to_s].join(':')
        task = to_task_name('-')

        case error_class
        when :TaskAbort
          Onering::Logger.warn(e.message, source)
          App::Metrics.increment("worker.tasks.all.aborts")
          App::Metrics.increment("worker.tasks.#{task}.aborts")

        when :TaskRetry
          Onering::Logger.warn(e.message, source)
          App::Metrics.increment("worker.tasks.all.retries")
          App::Metrics.increment("worker.tasks.#{task}.retries")

        else
          Onering::Logger.error(e.message, source)
          App::Metrics.increment("worker.tasks.all.failures")
          App::Metrics.increment("worker.tasks.#{task}.failures")

        end

        unless e.nil? or e.backtrace.nil?
          e.backtrace.each do |eb|
            Onering::Logger.debug(eb, source)
          end
        end
      end
    end
  end
end