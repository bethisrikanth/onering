require 'core/models/user'

class LdapUser < User
  class<<self
    def connect
      @_ldap = Net::LDAP.new({
        :host     => $CONFIG.value('global/auth/ldap/host'),
        :port     => ($CONFIG.value('global/auth/ldap/port') || 389),
        :auth     => {
          :method   => ($CONFIG.value('global/auth/ldap/method').to_sym rescue :simple),
          :username   => acct.fqusername("\\"),
          :password   => acct.dcpassword
        }
      })
    end

    def connected?
      (@_ldap ? true : false)
    end
  end

  def authenticate!(options={})
    if super
      return false
    end
  end
end