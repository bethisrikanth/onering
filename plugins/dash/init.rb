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
require 'dash/lib/graphite_graph'
require 'dash/models/graph'

module App
  class Base < Controller
    namespace '/api/dashboard' do
      get '/:name' do
        output({
          :title => "Test Dashboard",
          :panes => [{
            :type    => "graph",
            :name    => "ops.online.api.responsiveness.99th",
            :options => {
              :hide_legend => true,
              :line_width  => 2
            },
            :columns => 12
          },{
            :type    => "graph",
            :name    => "ops.online.api.connection_rate",
            :options => {
              :hide_legend => true,
              :line_width  => 2
            },
            :columns => 12
          }]
        })
      end

      get '/graph/:id' do
        graph = Dashboard::Graph.find(params[:id])
        return 404 if graph.nil?

        graph.options[:params] ||= {}
        graph.options[:params][:from] = params[:from]   if params[:from]
        graph.options[:params][:until] = params[:until] if params[:until]

        rv = graph.to_hash()
        rv[:data] = {
          :schema => [],
          :points => []
        }

        rv[:data][:points], rv[:data][:schema] = GraphiteGraph.query(rv)

        output(rv)
      end
    end
  end
end
