require 'auth/models/user'

class DeviceUser < User
  def authenticate!(options={})
    if super
      return false
    end
  end
end