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
