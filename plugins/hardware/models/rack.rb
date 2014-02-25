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
require 'model'
require 'assets/models/asset'
require 'organization/models/contact'

module Hardware
  class Rack < App::Model::Elasticsearch
    index_name "hardware_racks"

    field :name,        :string, :required => true
    field :description, :string
    field :site,        :string
    field :vendor,      :object
    field :height,      :integer, :required => true
    field :created_at,  :date,    :default => Time.now
    field :updated_at,  :date,    :default => Time.now


    def units()
      devices = Asset.urlquery("str:site/#{self.site}/str:rack/#{self.name}/virtual/not:true").to_a
      seen = Set.new()

      rv = []


      (1..self.height).to_a.reverse.collect do |u|
        nodes = devices.select{|i| [*i.properties.get(:unit, 0)].map(&:to_i).include?(u) }
        physical = (nodes.reject{|i| i.properties.get(:physical).nil? }.first.to_hash rescue {}).get('properties.physical',{})

        if physical.get('layout.height')
          node_units = ((u - physical.get('layout.height').to_i + 1)..u).to_a
        else
          node_units = nodes.collect{|i| [*i.properties.get(:unit, 0)] }.flatten.collect{|i| i.to_i }
        end

        unless seen.include?(u)
          seen += node_units

        # Hax: extract values from things
          unit = node_units.sort.reverse.uniq
          height = (unit.empty? ? 1 : (unit.max - unit.min) + 1)
          make  = nodes.collect{|i| i.properties.get(:make) }.uniq
          model = nodes.collect{|i| i.properties.get(:model) }.uniq

        # Hax II: normalize them
          unit = (unit.empty? ? [u] : unit)
          height = (height == 0 ? 1 : height)
          make = make.first if make.length == 1
          model = model.first if model.length == 1
          slots = {}

        # create slot objects keyed on slot number
          nodes.each{|i|
            slots[i.properties.get(:slot, 0)] = i.to_hash.reject{|k,v| k == 'properties'}.merge({
              :empty      => false,
              :properties => Hash[[:slot, :alert_state, :ip].collect{|j|
                [j, i.properties.get(j)]
              }.compact]
            })
          }

          rack_nodes = (1..physical.get('layout.slots.count', 0)).to_a.collect{|i|
            slots[i] || {
              :empty => true,
              :properties => {
                :slot => i
              }
            }
          }

          rack_nodes = slots.values if rack_nodes.empty?


        # push rack object onto rack
          rv << {
            :unit     => unit,
            :height   => height,
            :make     => (make.nil? ? nil : make.nil_empty),
            :model    => (model.nil? ? nil : model.nil_empty),
            :physical => physical,
            :nodes    => rack_nodes.sort{|a,b| a.get('properties.slot') <=> b.get('properties.slot') }.nil_empty
          }.compact
        end
      end

      rv
    end

    def serializable_hash(options = {})
      contact_id = (self.vendor || {}).get('contact_id')
      contact = Contact.find(contact_id).to_hash() if contact_id

      to_hash().deep_merge!({
        'units' => self.units(),
        'vendor' => {
          'contact' => contact
        }
      }.compact)
    end
  end
end