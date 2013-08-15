require 'model'
require 'assets/lib/helpers'

class NodeDefault < App::Model::Elasticsearch
  index_name "node_defaults"


  property :name,       :type => 'string'
  property :group,      :type => 'string'
  property :match,      :default => []
  property :apply,      :default => {}
  property :force,      :type => 'boolean', :default => false
  property :enabled,    :type => 'boolean', :default => true
  property :created_at, :type => 'date',    :default => Time.now
  property :updated_at, :type => 'date',    :default => Time.now

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

      NodeDefault.where({
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
    self.match = self.match.collect{|m| m.compact }.compact
    self.apply = self.apply
  end
end
