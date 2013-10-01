require 'model'
require 'assets/lib/helpers'

class NodeDefault < App::Model::Elasticsearch
  index_name "node_defaults"

  key :name,       :string
  key :group,      :string
  key :match,      :object,    :array => true
  key :apply,      :object
  key :force,      :boolean,   :default => false
  key :enabled,    :boolean,   :default => true
  key :created_at, :boolean,   :default => Time.now
  key :updated_at, :date,      :default => Time.now


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

    Asset.urlquery(query.join('/'))
  end

  class<<self
  # return all defaults that apply to the given device
    def defaults_for(device)
      rv = []

      NodeDefault.search({
        :filter => {
          :term => {
            :enabled => true
          }
        }
      }).each do |default|
        if (default.devices("str:id/#{device.id}").first.id rescue nil) == device.id
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
