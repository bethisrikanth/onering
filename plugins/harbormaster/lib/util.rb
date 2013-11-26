module Harbormaster
  module Autoscaling
    module Util
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def _consolidate(values, function)
          values ||= []
          values = values.compact
          return 0 if values.empty?

          case function.to_sym
          when :minimum
            return values.inject(values.first){|s,i|
              s=i if i<s; s
            }
          when :maximum
            return values.inject(values.first){|s,i|
              s=i if i>s; s
            }
          when :sum
            return values.inject(0){|s,i| s+=i }
          when :count
            return values.length
          else #average
            return (values.inject(0){|s,i| s+=i } / values.length)
          end
        end
      end
    end
  end
end