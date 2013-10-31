require 'onering'

module Automation
  module Tasks
    class ResqueTask
      extend FlowControl

      TASKPATH = [
        File.join(ENV['PROJECT_ROOT'], 'plugins', '*', 'rqtasks')
      ]

      def self.load_all()
        TASKPATH.each do |path|
          Dir["#{path}/**/*.rb"].each do |f|
            if Automation::Tasks::Base.register(f)
              begin
                Onering::Logger.debug("Loading Resque task #{f}", "Automation::Tasks::ResqueTask")
                require f
              rescue LoadError => e
                Onering::Logger.error("Unable to load task #{f}: #{e.message}", "Automation::Tasks::ResqueTask")
                next
              end
            end
          end
        end
      end

      def self.to_task_name()
        self.name.split('::')[2..-1].map(&:underscore).join('/')
      end

      def self.before_perform(*args)
        Onering::Logger.info("Performing task", to_task_name())
      end

      def self.on_failure(e, *args)
        source = [to_task_name(), e.class.name].join(':')
        Onering::Logger.error(e.message, source)

        e.backtrace.each do |eb|
          Onering::Logger.debug(eb, source)
        end
      end
    end
  end
end