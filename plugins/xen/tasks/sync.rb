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

require 'assets/models/asset'

module Automation
  module Tasks
    module Xen
      class Sync < Task
        def self.perform(*args)
          hosts = {}

          guests = Asset.urlquery('xen.uuid').to_a

          if not guests.empty?
            log("Linking #{guests.length} Xen guests to their parent hosts")

            guests.each do |guest|
              uuid = guest.properties.get('xen.uuid')
              parent = (hosts[uuid] || Asset.urlquery("xen.guests/#{uuid}").to_a.first)

              if parent
              # cache the parent for the duration of this call
                hosts[uuid] ||= parent

                guest.parent_id = parent.id
                guest.save()
              end
            end
          end

          return nil
        end
      end
    end
  end
end
