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

require 'net/ping'
require 'rubyipmi'
require 'assets/models/asset'
require 'ipmi/lib/asset_extensions'

module Automation
  module Tasks
    module Ipmi
      class Execute < Task


        def self.perform(id, command, options={})
          node = Asset.find(id)
          fail("Cannot execute IPMI command on non-existent device #{id}") unless node
          fail("IPMI node extensions not properly loaded") unless node.respond_to?(:ipmi_command)

          if node.ipmi_command(command, options)
            info("IPMI command sent successfully")
          else
            fail("IPMI command failed")
          end
        end
      end
    end
  end
end
