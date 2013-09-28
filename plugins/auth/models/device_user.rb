require 'auth/models/user'

class DeviceUser < User
  index_name    "users"
  document_type "device_user"

  key :name,         :string
  key :email,        :string
  key :client_keys,  :object
  key :tokens,       :string,  :array => true
  key :options,      :object
  key :logged_in_at, :date
  key :created_at,   :date,    :default => Time.now
  key :updated_at,   :date,    :default => Time.now

  def authenticate!(options={})
    if super
      return false
    end
  end
end