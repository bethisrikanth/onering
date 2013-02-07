require 'model'

class User < App::Model::Base
  set_collection_name "users"

  timestamps!
  
  key :name,         String
  key :logged_in_at, Time

  def groups
    Group.where({
      :users => id
    }).collect{|i| i.id } rescue []
  end

  def to_h
    super.merge({
      :groups => groups
    })
  end

  def capabilities
  # find all capabilites where this user or any of its groups are named
  # get the flattened list of all capabilities, return it
    Capability.where({
      :$or => [{
        :users => id
      }, {
        :groups => {
          :$in => groups
        }
      }]
    }).collect{|c|
      (c.capabilities ? c.capabilities : c.id)
    }.flatten
  end

  def authenticate!(options={})
    not App::Config.get('global.authentication.prevent')
  end

  def capability?(key, args=nil)
    send("capability_#{key}", args)
  # rescue
  #   false
  end

  class<<self
    def capability(name, &block)
      send :define_method, "capability_#{name}" do |*args|
        if block_given?
          yield name, self, (args.flatten rescue [])
        else
          Capability.user_can?(self.id, name)
        end
      end

      true
    end

    Dir[File.join(ENV['PROJECT_ROOT'],'plugins','*','capabilities','*.rb')].each do |c|
      c = c.sub(File.join(ENV['PROJECT_ROOT'],'plugins',''), '')
      require c.sub(/\.rb$/,'')
    end
  end
end