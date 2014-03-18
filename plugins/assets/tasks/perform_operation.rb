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

require 'set'
require 'assets/models/asset'

module Automation
  module Tasks
    module Assets
      class PerformOperation < Task
        def self.perform(id, operation, *args)
          fail("UNTESTED")


          asset = Asset.find(id)
          fail("Cannot find asset #{id}") if asset.nil?

          case operation.to_sym
          when :set
            info("Setting field #{args[0]} for asset #{asset.id}")
            asset.set(args[0], args[1])

          when :unset
            info("Removing field #{args[0]} for asset #{asset.id}")
            asset.unset(args[0])

          when :push
            info("Pushing #{args[1..-1].length} values onto field #{args[0]} for asset #{asset.id}")

            args[1..-1].each do |i|
              asset.push(args[0], i)
            end

          when :pop
            info("Popping #{args[1].to_i} values off of field #{args[0]} for asset #{asset.id}")

            args[1].to_i.times do |i|
              asset.pop(args[0])
            end

          when :sync
            info("Syncing asset #{asset.id}")
            asset.save({
              :reload => false
            },{
              :refresh => false
            })

            return true

          when :destroy
            info("Destroying asset #{asset.id}")
            asset.destroy()
            return true

          else
            fail("No such operation #{operation}")
          end

          asset.save()
        end
      end
    end
  end
end