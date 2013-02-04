require 'model'

class User < App::Model::Base  
  set_collection_name "users"

  key :name,            String

  def authenticate!(options={})
    !Config.get('global.authentication.prevent')
  end
end