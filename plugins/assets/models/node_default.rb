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

require 'model'
require 'assets/lib/helpers'

class NodeDefault < App::Model::Elasticsearch
  index_name "node_defaults"

  field :name,       :string
  field :group,      :string
  field :order,      :integer,   :default => 0
  field :match,      :object,    :array => true
  field :apply,      :object
  field :force,      :boolean,   :default => false
  field :enabled,    :boolean,   :default => true
  field :created_at, :date,      :default => Time.now
  field :updated_at, :date,      :default => Time.now


  before_save  :_compact

  def devices(filter=nil)
    query = []

    if filter.is_a?(Hash)
      filter.each do |k,v|
        query << k
        query << v
      end
    elsif filter.is_a?(String)
      query += filter.split('/')
    end

    [*self.match].each{|m|
      query << (m['type'].nil? ? '' : m['type']+':')+m['field']
      query << (m['test'].nil? ? '' : m['test']+':')+m['value'] if m['value']
    }

    Asset.ids(query.join('/'))
  end

  def enabled?()
    return (self.enabled == true)
  end

  def asset_matches?(node)
    self.match.each do |m|
      m = m.symbolize_keys()

    # get the candidate value, return false if not found
      value = node.get(m[:field])

    # convert type if necessary
      if m[:type].nil?
        if value.is_a?(Array)
          value = value.collect{|i| i.to_s.autotype() }
        else
          value = value.to_s.autotype()
        end

        m[:value] = m[:value].to_s.autotype()
      else
        if value.is_a?(Array)
          value = value.collect{|i| i.to_s.convert_to(m[:type]) }
        else
          value = value.to_s.convert_to(m[:type])
        end

        m[:value] = m[:value].to_s.convert_to(m[:type])
      end

      begin
        case m[:test].to_s
        when 'lt', 'before'
          return false if value.nil?
          return false if not value < m[:value]
        when 'lte'
          return false if value.nil?
          return false if not value <= m[:value]
        when 'gt'
          return false if value.nil?
          return false if not value > m[:value]
        when 'gte', 'since'
          return false if value.nil?
          return false if not value >= m[:value]
        when 'not'
          if value.is_a?(Array)
            return false if value.include?(m[:value])
          else
            return false if value == m[:value]
          end

        when 'matches'
          rv = false

        # perform match on all array elements
          if value.is_a?(Array)
            value.each do |v|
              next if v.is_a?(Array)
              next if v.is_a?(Hash)

            # break true on first positive match
              if v =~ Regexp.new(m[:value])
                rv = true
                break
              end
            end
          elsif value.to_s =~ Regexp.new(m[:value])
            rv = true
          end

          return false if rv === false
        else
          if value.is_a?(Array)
            return false if not value.include?(m[:value])
          else
            return false if not value == m[:value]
          end
        end
      rescue Exception => e
        Onering::Logger.warn("Encountered error applying node default: #{e.class.name} - #{e.message}", "NodeDefault")
        Onering::Logger.debug("Node Default ID #{self.id}, field #{m[:field]}. Node value = #{value}, applying #{m[:value]}", "NodeDefault")
        return false
      end
    end

    return true
  end

  class<<self
  # return all defaults that apply to the given device
    def defaults_for(node)
      rv = []

      NodeDefault.search({
        :sort => [{:order => :asc}],
        :filter => {
          :term => {
            :enabled => true
          }
        }
      }).each do |default|
        if default.asset_matches?(node)
          rv << default
          next
        end
      end

      return rv
    end
  end


private
  def _compact
    unless self.match.nil?
      self.match = self.match.collect{|m| m.compact }.compact
    end
  end
end
