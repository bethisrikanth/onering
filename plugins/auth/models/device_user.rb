require 'auth/models/user'

class DeviceUser < User
  index_name    "users"
  document_type "device_user"

  property :name,         :type => 'string'
  property :email,        :type => 'string'
  property :client_keys,  :default => {}
  property :tokens,       :default => []
  property :options,      :default => {}
  property :logged_in_at, :type => 'date'
  property :created_at,   :type => 'date',    :default => Time.now
  property :updated_at,   :type => 'date',    :default => Time.now

  def authenticate!(options={})
    if super
      return false
    end
  end
end