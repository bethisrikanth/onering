require 'model'
require 'assets/models/device'

class Navigation < App::Model::Base
  include App::Model::Taggable

  set_collection_name "navigation"

  key :name,    String
  key :items,   Array
  key :user_id, String
end