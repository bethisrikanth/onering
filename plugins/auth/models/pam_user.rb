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

require 'rpam'
require 'auth/models/user'

class PamUser < User
  index_name    "users"
  document_type "pam_user"

  inherit_fields!

  def authenticate!(options={})
    if super
      service = App::Config.get('global.authentication.methods.pam.service', 'onering')
      options[:username] = id

      begin
      # using rpam-ruby19 (https://github.com/canweriotnow/rpam-ruby19)
        if Rpam.respond_to?(:auth)
          return Rpam.auth(options[:username], options[:password], {
            :service => service
          })
        else
      # rpam legacy (http://rpam.rubyforge.org/)
      #
      # NOTE: this version does not work on Ruby 1.8 and does not support
      #       specifying the PAM service name (hardcoded to 'rpam')
      #       > e.g. /etc/pam.d/rpam
      #
          include Rpam
          return authpam(options[:username], options[:password])
        end

        return false
      rescue Exception => e
        STDERR.puts "PAM Error: #{e.class.name}: #{e.message}"
      end
    end
  end
end
