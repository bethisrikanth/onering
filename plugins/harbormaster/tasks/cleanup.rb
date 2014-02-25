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
        class Cleanup < Task
          DEFAULT_MESOS_API_PORT=5050
          DEFAULT_MESOS_API_STATEFILE='/master/state.json'
          MARATHON_TASK_MIN_STALE_TIME=60

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

              cluster_nodes = Asset.urlquery("mesos.masters.options.cluster/#{task.cluster}")

              cluster_nodes.each do |node|
                debug("Getting cluster state from cluster master #{node.get(:fqdn)}")

                response = Net::HTTP.get_response(URI("http://#{[*node.get(:ip,[])].first}:#{DEFAULT_MESOS_API_PORT.to_i}#{DEFAULT_MESOS_API_STATEFILE}"))
                rv = MultiJson.load(response.body)

                unless rv.is_a?(Hash)
                  warn("Invalid or incomplete response from cluster master #{node.get(:fqdn)}")
                  next
                end

                running_marathon_tasks = rv.get(:frameworks,[]).collect{|i|
                  i.get(:tasks,[])
                }.flatten.select{|i|
                  i['executor_id'] =~ Regexp.new("^marathon-harbormaster-#{task.id}_\\d+-\\d{13,}$")
                }.select{|i|
                  i['state'] == 'TASK_RUNNING'
                }.select{|i|
                  (Time.now - Time.at(i['executor_id'].split('-').last.to_i / 1000)).to_i > MARATHON_TASK_MIN_STALE_TIME
                }.sort{|a,b|
                  a['executor_id'] <=> b['executor_id']
                }.reverse

              # how many more running tasks are there than there should be?
                overflow = 0

                if task.enabled === true
                  overflow = (task.instances - running_marathon_tasks.length)
                  warn("Task set to #{task.instances} instances, but found #{running_marathon_tasks.length} running instances in the #{task.cluster} cluster")
                elsif running_marathon_tasks.length > 0
                  overflow = running_marathon_tasks.length
                  warn("Task is disabled, but found #{running_marathon_tasks.length} running instances in the #{task.cluster} cluster")
                end

                if overflow > 0
                  warn("Removing #{overflow} oldest tasks")

                  running_marathon_tasks[0..(overflow-1)].each do |t|
                    error("TODO: Remove Marathon task #{t['id']}")
                  end
                end

                break
              end
            end
          end
        end
      end
    end
  end
end
