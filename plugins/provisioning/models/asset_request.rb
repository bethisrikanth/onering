require 'model'

class AssetRequest < App::Model::Elasticsearch
  index_name "asset_requests"

  before_save :_intify_quantities
  before_save :_compact_notes

  key :deliver_by,      :date

  key :user_id,         :string
  key :team,            :string
  key :quantity,        :object
  key :service,         :string
  key :notes,           :object, :array => true
  key :created_at,      :date,    :default => Time.now
  key :updated_at,      :date,    :default => Time.now


  def to_h
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