require 'model'
require 'assets/lib/helpers'

class NodeDefault < App::Model::Elasticsearch
  index_name "node_defaults"

  field :name,       :string
  field :group,      :string
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

  def asset_matches?(node)
    self.match.each do |m|
      m = m.symbolize_keys()

    # get the candidate value, return false if not found
      value = node.get(m[:field])

    # convert type if necessary
      if m[:type].nil?
        value = value.to_s.autotype()
        m[:value] = m[:value].to_s.autotype()
      else
        value = value.to_s.convert_to(m[:type])
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
          return false if value == m[:value]
        else
          return false if not value == m[:value]
        end
      rescue Exception => e
        Onering::Logger.warn("Encountered error applying node default: #{e.class.name} - #{e.message}", "NodeDefault")
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
