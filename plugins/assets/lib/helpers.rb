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
    require 'assets/lib/mongo_urlquery_parser'

  # TODO: fix external references to this to stop this madness
    TOP_LEVEL_FIELDS = MongoUrlqueryParser::TOP_LEVEL_FIELDS

    def urlquerypath_to_mongoquery(query)
      if query
        query.gsub!(/(?:^\/|\/$)/, '')
        @@_parser ||= MongoUrlqueryParser.new()
        rv = @@_parser.parse(query).to_mongo_query()
        return rv
      end
    end
  end
end