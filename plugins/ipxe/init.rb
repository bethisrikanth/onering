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
require 'assets/models/asset'

module App
  class Base < Controller
    namespace '/api/ipxe' do
      get '/boot' do
        content_type 'text/plain'

        if params[:id]
          device = Asset.find(params[:id])
        elsif params[:mac] and not params[:mac].empty?
        # TODO: order by collected_at DESC
          device = Asset.urlquery("mac|network.interfaces.mac/#{params[:mac]}").to_a.first
        elsif params[:uuid] and not params[:uuid].empty?
        # TODO: order by collected_at DESC
          device = Asset.urlquery("uuid/#{params[:uuid]}").to_a.first
        end

        liquid "ipxe/boot".to_sym, :locals => {
          :device => (device.to_hash() rescue nil),
          :config => Config.get('provisioning.boot')
        }
      end
    end
  end
end
