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
    module Assets
      class Delete < Task
        def self.perform(ids, type=:list)
          nodes = []

          case type.to_sym
          when :query
            [*type].each do |query|
              nodes += Asset.urlsearch(query)
            end

            abort("No nodes matched query #{[*type].join(', ')}") if nodes.empty?

          when :list
            nodes = Asset.find([*ids])
            abort("No nodes found") if nodes.empty?

          else
            fail("Unknown input type #{type}")
          end

          info("Deleting #{nodes.length} nodes: #{nodes.length <= 5 ? nodes.collect{|i| i.id }.join(', ') : nodes[0..4].collect{|i| i.id }.join(', ')+'...'}")

          nodes.each do |node|
            id = node.id

            begin
              node.destroy()
            rescue Exception => e
              warn("Error destroying node #{id}: #{e.message}", e.class.name)
              next
            end
          end
        end
      end
    end
  end
end
