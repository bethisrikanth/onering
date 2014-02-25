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

require 'controller'
require 'organization/models/contact'

module App
  class Base < Controller
    namespace '/api/org' do
      namespace '/contacts' do
        get '/find/?' do
          Contact.all.collect{|i| i.to_h }.to_json
        end

        get '/find/:field/:query' do
          output(Contact.urlquery([params[:field], params[:query]].join('/')).collect{|i|
            i.to_hash()
          })
        end

        get '/:id' do
          output(Contact.find(params[:id]))
        end
      end
    end
  end
end
