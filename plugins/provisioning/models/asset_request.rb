require 'model'

class AssetRequest < App::Model::Base
  set_collection_name "asset_requests"

  timestamps!

  key :deliver_by,      Time

  key :user_id,         String
  key :team,            String
  key :quantity,        Hash
  key :service,           String

  key :notes,           Array
end