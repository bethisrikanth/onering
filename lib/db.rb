module App
  module Database
    class DatabaseNotFound < Exception; end

    class Base
      class<<self
        def load(name, config=nil)
          config = Config.get("database/#{name}") unless config
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