require 'auth/models/user'

class DeviceUser < User
  set_collection_name "device_users"

  def authenticate!(options={})
    if super
      return false
    end
  end
end