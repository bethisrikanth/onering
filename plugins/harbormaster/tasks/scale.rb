require 'harbormaster/models/task'
require 'assets/models/asset'

module Automation
  module Tasks
    module Harbormaster
      module Tasks
        class Scale < Task
          def self.perform(task_id=nil, *args)
            if task_id.nil?
              tasks = ::Harbormaster::Task.all()
            else
              tasks = [::Harbormaster::Task.find(task_id)]
            end

            tasks.each do |task|
              if task.nil?
                warn("Cannot find Harbormaster task#{task_id ? ' '+task_id.to_s : ''}, skipping...")
                next
              end

              if task.scale()
                info("Successfully dispatched scale command for #{task.name} (#{task.id}), now at #{task.instances} instances")
              else
                error("Scale command was unsuccessful for #{task.name} (#{task.id}), task is at #{task.instances} instances")
              end
            end
          end
        end
      end
    end
  end
end
