require 'model'

class Contact < App::Model::Elasticsearch
  key :name,            :string
  key :tags,            :string,   :array => true
  key :properties,      :object
  key :mail,            :object
  key :phones,          :object
  key :address,         :object
end
