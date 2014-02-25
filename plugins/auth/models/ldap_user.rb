# Copyright 2012 Outbrain, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'auth/models/user'

class LdapUser < User
  class<<self
    def connect
      @_ldap = Net::LDAP.new({
        :host     => App::Config.value('global/auth/ldap/host'),
        :port     => (App::Config.value('global/auth/ldap/port') || 389),
        :auth     => {
          :method   => (App::Config.value('global/auth/ldap/method').to_sym rescue :simple),
          :username => acct.fqusername("\\"),
          :password => acct.dcpassword
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