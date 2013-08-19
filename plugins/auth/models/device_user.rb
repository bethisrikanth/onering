require 'auth/models/user'

class DeviceUser < User
  index_name    "users"
  document_type "device_user"

  def authenticate!(options={})
    if super
      return false
    end
  end
end