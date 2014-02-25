# Copyright 2012 Outbrain, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'model'

class Group < App::Model::Elasticsearch
  index_name "groups"

  field :name,       :string
  field :users,      :string,  :array => true
  field :created_at, :date,    :default => Time.now
  field :updated_at, :date,    :default => Time.now

  def capabilities
    Capability.urlquery("groups/#{self.id}").collect{|c|
      (c.capabilities ? c.capabilities : c.id)
    }.flatten
  end
end