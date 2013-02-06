require 'model'

class Capability < App::Model::Base
  set_collection_name "capabilities"

  key :users, Array

  class<<self
    def users_that_can(key)
      find(key).users rescue []
    end
  end
end