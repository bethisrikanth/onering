require 'model'

class AssetRequest < App::Model::Elasticsearch
  index_name "asset_requests"

  before_save :_intify_quantities
  before_save :_compact_notes

  field :deliver_by,      :date

  field :user_id,         :string
  field :team,            :string
  field :quantity,        :object
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