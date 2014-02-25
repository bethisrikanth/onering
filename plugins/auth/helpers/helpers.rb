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

module App
  module Helpers
    def anonymous?(path)
      App::Config.get('global.authentication.public_paths',[]).each do |p|
        return true if path =~ Regexp.new("^#{p}$")
      end

      return false
    end

    def ssl_verified?
      (request.env['HTTP_X_CLIENT_VERIFY'] === 'SUCCESS')
    end

    def ssl_hash(type)
    # looks for ENVVAR X-SSL-(.*)
      (request.env["HTTP_X_SSL_#{type.to_s.upcase}"] ? request.env["HTTP_X_SSL_#{type.to_s.upcase}"].to_s.sub(/^\//,'').split('/').collect{|i| i.split('=') } : nil)
    end
  end
end
