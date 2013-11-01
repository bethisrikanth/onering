module Automation
  module Tasks
    module Util
      def abort(message)
        raise TaskAbort.new(message)
      end

      def retry(message)
        raise TaskRetry.new(message)
      end

      def fail(message)
        raise TaskFail.new(message)
      end

      def error(message, source=nil)
        log(message, :error, source)
      end

      def warn(message, source=nil)
        log(message, :warn, source)
      end

      def info(message, source=nil)
        log(message, :info, source)
      end

      def debug(message, source=nil)
        log(message, :debug, source)
      end


      def log(message, severity=:info, source=nil)
        Onering::Logger.log(severity, message, (self.respond_to?(:to_task_name) && self.to_task_name())+(source.nil? ? '' : ':'+source.to_s))
      end
    end
  end
end