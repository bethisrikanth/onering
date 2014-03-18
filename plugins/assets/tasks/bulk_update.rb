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
      class BulkUpdate < Task
        def self.perform(query, operation, *args)
          fail("UNTESTED")

          assets = Asset.ids(query)
          return nil if assets.empty?

          info("Performing bulk operation #{operation} on #{assets.length} assets")

          assets.each do |i|
            run_low('assets/perform_operation', i, operation, *args)
          end
        end
      end
    end
  end
end