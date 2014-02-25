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

class AssetRequest < App::Model::Elasticsearch
  index_name "asset_requests"

  before_save :_intify_quantities
  #before_save :_compact_notes

  field :deliver_by,      :date

  field :user_id,         :string
  field :team,            :string
  field :quantity,        :object,  :default => {}
  field :service,         :string
  field :notes,           :object,  :array => true
  field :created_at,      :date,    :default => Time.now
  field :updated_at,      :date,    :default => Time.now


  def to_hash()
    super.to_hash.merge({
      'total' => total()
    })
  end


  def total()
    self.quantity.collect{|k,v| v.to_i }.inject(0){|s,i| s+=i }
  end

  def _intify_quantities()
    self.quantity = Hash[self.quantity.collect{|k,v|
      [k, v.to_i]
    }]
  end

  def _compact_notes()
    self.notes = self.notes.flatten.collect{|i| i.compact }.compact
  end
end