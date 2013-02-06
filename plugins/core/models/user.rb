require 'model'
require 'core/models/capability'

class User < App::Model::Base
  set_collection_name "users"

  key :name,            String

  def authenticate!(options={})
    return !App::Config.get('global.authentication.prevent')
  end

  def capability(key, *args)
    begin
      send("capability_#{key}", args)
    rescue
      false
    end
  end

  def capability_update_user(*args)
    (id == args.first) || (Capability.users_that_can(:update_user).include?(id))
  end
end