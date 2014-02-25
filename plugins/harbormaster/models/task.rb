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

require 'model'
require 'httparty'

module Harbormaster
  class Task < App::Model::Elasticsearch
    index_name "harbormaster_tasks"

    field :name,       :string
    field :cluster,    :string
    field :enabled,    :boolean,  :default => true
    field :instances,  :integer
    field :task,       :object,   :default => {}
    field :resources,  :object,   :default => {}
    field :scaling,    :object,   :default => ({
      :mode          => :static,
      :fail_behavior => 'nothing',
      :config        => {}
    })

    field :created_at,      :date,      :default => Time.now
    field :updated_at,      :date,      :default => Time.now
    field :last_checked_at, :date
    field :last_scaled_at,  :date


  # dynamic_scaling_instance_count
  #
  # if scaling mode=dynamic, this will perform the configured check to retrieve
  # to calculate what the current number of active instances should be for this
  # task
  #
    def dynamic_scaling_instance_count(test_value=nil)
    # return current instance count unless we're dynamic
    #   >>///====/WHOOOSH/===//DYNAMISM!//>
    #
      return self.instances unless self.scaling.get(:mode) == 'dynamic'

      begin
        check_type = self.scaling.get('config.type')
        raise LoadError.new if check_type.nil?
        require "harbormaster/lib/autoscaling/#{check_type}"
        klass = (Harbormaster::Autoscaling.const_get(check_type.camelize) rescue nil)
        raise LoadError.new unless klass

        rv = klass.instance_count(self, test_value)
        self.last_checked_at = Time.now

        return (rv.nil? ? self.instances : rv)

      rescue LoadError
        Onering::Logger.error("Unable to find dynamic scaling check for type #{check_type}")
        return self.instances
      end
    end


    def instance_count(force_instances=nil, test_value=nil)
    # determine target instance count
      if not force_instances.nil?
        target_instances = force_instances.to_i
      elsif self.scaling.get(:mode) == 'dynamic'
        target_instances = dynamic_scaling_instance_count(test_value)
      else
        target_instances = self.instances
      end

    # apply bounds if they exist
    # --------------------------------------------------------------------------
    #
    # handle instances being unset; attempt to apply default or leave alone
      if target_instances.nil?
        if not self.scaling.get(:default).nil?
          target_instances = self.scaling.get(:default).to_i
        else
          Onering::Logger.error("Instances not set and no default specified for task #{self.id}")
          return false
        end

    # handle below minimum
      elsif not self.scaling.get(:minimum).nil? and target_instances < self.scaling.get(:minimum).to_i
        target_instances = self.scaling.get(:minimum).to_i

    # handle above maximum
      elsif not self.scaling.get(:minimum).nil? and target_instances > self.scaling.get(:maximum).to_i
        target_instances = self.scaling.get(:maximum).to_i
      end

      return target_instances
    end


  # scale
  #
  # will dispatch the requested scaling state (including resource utilization changes)
  # to the associated cluster
  #
    def scale(force_instances=nil)
      if self.cluster.nil?
        Onering::Logger.error("Task #{self.id} is missing the cluster attribute")
        return false
      end

      self.instances = self.instance_count(force_instances)


    # persist the target instances count
    # --------------------------------------------------------------------------
      if self.save()
        Onering::Logger.debug("Task #{self.id} target instances set to #{self.instances}")

        marathon_node = nil
        cluster_node_apps = nil

      # verify connectivity to the compute cluster
      # ------------------------------------------------------------------------
        Asset.urlquery("mesos.masters.options.cluster/#{self.cluster}").each do |node|
          url = "http://#{node.get(:fqdn)}:8080/v1/apps"
          response = HTTParty.get(url)

          if response.code == 200
            cluster_node_apps = MultiJson.load(response.body)
            marathon_node = node
            break
          else
            Onering::Logger.warn("Unable to communicate with Marathon on node #{node.id} via #{url}")
            next
          end
        end

        if marathon_node.nil?
          Onering::Logger.error("Cannot contact any Marathon nodes")
          return false
        end

      # build the request
      # ------------------------------------------------------------------------
        marathon_task_name = "harbormaster-#{self.id}"
        cluster_app = cluster_node_apps.select{|i| i.get(:id) == marathon_task_name }.first

        body = {
          :id        => marathon_task_name,
          :instances => self.instances,
          :mem       => self.resources.get(:memory),
          :cpus      => self.resources.get(:cpu),
          :cmd       => self.task.get(:name),
          :env       => self.resources.get(:environment,{})
        }

      # send request (with retries!)
      # ------------------------------------------------------------------------
        scale_success = false

        3.times.each do
          break if scale_success === true

          catch(:retry) do
            response = nil
            url      = nil

          # task not found in cluster, start it
            if cluster_app.nil?
              if self.enabled === true
                url = "http://#{marathon_node.get(:fqdn)}:8080/v1/apps/start"
                response = HTTParty.post(url, {
                  :headers => {
                    'Content-type' => 'application/json'
                  },
                  :body => MultiJson.dump(body)
                })
              else
                Onering::Logger.debug("Task #{self.id} is disabled and absent from Marathon, skipping...")
                return true
              end

          # task IS found in cluster
            else
              payload = MultiJson.dump(Hash[body.select{|k,v|
                [:id, :instances].include?(k.to_sym)
              }])

            # if these properties are changing, stop the existing service first
              if cluster_app['cmd'] != body[:cmd] or
                 cluster_app['mem'].to_f != body[:mem].to_f or
                 cluster_app['cpus'].to_f != body[:cpus].to_f
              then
                Onering::Logger.info("Launch parameters have changed for task #{self.id} (Marathon task #{marathon_task_name}), relaunching...")

                response = HTTParty.post("http://#{marathon_node.get(:fqdn)}:8080/v1/apps/stop", {
                  :headers => {
                    'Content-type' => 'application/json'
                  },
                  :body => payload
                })

                if response.code >= 300
                  Onering::Logger.warn("Received HTTP #{response.code} while stopping task #{self.id} (Marathon task #{marathon_task_name})")
                end

                cluster_app = nil
                throw :retry
              end

            # stop it if we're not enabled
              if self.enabled == false
                Onering::Logger.debug("Sending stop command to #{marathon_node.get(:fqdn)} for task #{marathon_task_name}")

                url = "http://#{marathon_node.get(:fqdn)}:8080/v1/apps/stop"
                response = HTTParty.post(url, {
                  :headers => {
                    'Content-type' => 'application/json'
                  },
                  :body => payload
                })

            # scale it to n instances otherwise
              else
                Onering::Logger.debug("Sending scale command to #{marathon_node.get(:fqdn)} for task #{marathon_task_name}")

                url = "http://#{marathon_node.get(:fqdn)}:8080/v1/apps/scale"
                response = HTTParty.post(url, {
                  :headers => {
                    'Content-type' => 'application/json'
                  },
                  :body => payload
                })
              end
            end

            if response.code < 300
              scale_success = true
              next
            end

            Onering::Logger.warn("Received response HTTP #{response.code} from #{url}")
          end
        end

        if scale_success === true
        # save the last scaled time
        # ----------------------------------------------------------------------
          self.last_scaled_at = Time.now
          self.save()

          return self
        else
          Onering::Logger.error("Attempt to scale task #{self.id} (Marathon task #{marathon_task_name}) failed")
          return false
        end

      else
        return false
      end
    end
  end
end
