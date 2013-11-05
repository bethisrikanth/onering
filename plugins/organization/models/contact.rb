require 'model'

class Contact < App::Model::Elasticsearch
  field :name,            :string
  field :tags,            :string,   :array => true
  field :properties,      :object
  field :mail,            :object
  field :phones,          :object
  field :address,         :object

  field_prefix            :properties
end
