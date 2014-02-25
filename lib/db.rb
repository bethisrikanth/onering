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
  module Database
    class DatabaseNotFound < Exception; end

    class Base
      class<<self
        def load(name, config=nil)
          config = Config.get("database.#{name}") unless config
          raise "Database driver required for #{name}" unless config['type']
          @_db = {} unless @_db

          if not @_db[name] # load only if it's the first time
            if require "db/#{config['type']}"
              @_db[name] = App::Database.const_get(config['type'].capitalize).load(name, config)
            else
              raise DatabaseNotFound, name
            end
          end
        end

        def load_all
          Config.get!('database').each do |name, config|
            next if config.get(:standalone, false)
            load(name, config)
          end
        end

        def get(name)
          begin
            raise Exception unless @_db[name]
          rescue Exception
            load_database(name)
            retry
          end
        end
      end
    end
  end
end
