require 'model'
require 'assets/lib/helpers'

class NodeDefault < App::Model::Base
  set_collection_name "node_defaults"

  timestamps!

  key :match, Array
  key :apply, Hash
  key :force, Boolean, :default => false

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

    Device.urlsearch(query.join('/'))
  end

  class<<self
  # return all defaults that apply to the given device
    def defaults_for(device)
      rv = []

      NodeDefault.all.each do |default|
        if (default.devices("str:id/#{device.id}").first.id rescue nil) == device.id
          rv << default
          next
        end
      end

      return rv
    end
  end
end
