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

require 'controller'
require 'ipmi/lib/asset_extensions'

module App
  class Base < Controller
    namespace '/api/devices' do
      get '/:id/ipmi/:command/?*' do
        node = Asset.find(params[:id])
        return 404 unless node

        if params[:splat].first.empty?
          args = []
        else
          args = params[:splat].first.split('/').collect{|i|
            i.autotype()
          }
        end

        output({
          :id      => node.id,
          :bmc     => {
            :ip => node.get(:ipmi_ip),
            :netmask => node.get(:ipmi_netmask),
            :gateway => node.get(:ipmi_gateway),
            :mac => node.get(:ipmi_macaddress)
          },
          :command => params[:command],
          :arguments => args,
          :result  => node.ipmi_command(params[:command], {
            :arguments => args
          })
        })
      end
    end
  end
end
