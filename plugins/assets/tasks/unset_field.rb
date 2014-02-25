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
require 'assets/models/node_default'

module Automation
  module Tasks
    module Assets
      class UnsetField < Task
        def self.perform(field, query=nil)
          if query.nil?
            nodes = Asset.ids()
          else
            nodes = Asset.ids(query)
            abort("No nodes found for query #{query}") if nodes.empty?
          end

          field = field.split('.')
          field[-1] = '@'+field[-1]
          field = (['properties']+field).join('.')

          nodes.each do |id|
          # queue this node
            # run_low('assets/update', {
            #   'id' => id
            # }.set(field, nil))

            info({
              'id' => id
            }.set(field, nil).inspect)
          end
        end
      end
    end
  end
end