require 'model'
require 'assets/models/asset'

class Navigation < App::Model::Elasticsearch
  index_name "navigation"

  key :name,    :string
  key :items,   :string, :array => true
  key :user_id, :string
end