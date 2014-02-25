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
    namespace '/api/rundeck' do
      get '/nodes/?*' do
        nodes = Asset.urlquery("bool:orchestrate/not:false/"+params[:splat].first)
        return 404 if nodes.empty?

        content_type 'text/x-yaml'

        return YAML.dump(nodes.collect{|node|
          rv = {
            'nodename'  => node.get('rundeck.name', node.id),
            'hostname'  => (node.get(params[:hostname] || Config.get('automation.rundeck.fields.hostname') || 'fqdn') || node.name || node.id),
            'username'  => (params[:username] || node.get('rundeck.user', Config.get('automation.rundeck.user', 'rundeck'))),
            'tags'      => node.tags,
            'osVersion' => node.get('version'),
            'osName'    => node.get('distro'),
            'osArch'    => node.get('arch')
          }

          Config.get('automation.rundeck.fields',{}).each do |field, value|
            next if field.to_s == 'hostname'
            value = node.get(value)
            rv[field] = value
          end

          Hash[rv.compact.collect{|k,v|
            if v.is_a?(Array)
              [k, v.collect{|i| i.to_s }]
            else
              [k, v.to_s]
            end
          }]
        })
      end
    end
  end
end
