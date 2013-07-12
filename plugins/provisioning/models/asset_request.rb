require 'model'

class AssetRequest < App::Model::Base
  set_collection_name "asset_requests"

  before_save :_intify_quantities
  before_save :_compact_notes

  timestamps!

  key :deliver_by,      Time

  key :user_id,         String
  key :team,            String
  key :quantity,        Hash
  key :service,         String
  key :notes,           Array


  def to_h
    super.to_h.merge({
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