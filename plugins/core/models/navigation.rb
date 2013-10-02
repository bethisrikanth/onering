require 'model'
require 'assets/models/asset'

class Navigation < App::Model::Elasticsearch
  index_name "navigation"

  field :name,    :string
  field :items,   :string, :array => true
  field :user_id, :string
end