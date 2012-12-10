
module App
  module Database
    class Mongo
      require 'mongo'
      require 'mongo_mapper'

      class<<self
        def load(name, config)
          conn = {
            :safe => config['safe'].to_s.to_bool
          }

          if config['logging'] === true
            logger = Logger.new(File.join(ENV['PROJECT_ROOT'], "mongo-#{name}.log"))
            conn[:logger] = logger
          end

          @database = name
          @connection = ::Mongo::Connection.new(
            (config['host'] || 'localhost'),
            (config['port'] || 27017).to_i,
            conn
          )

          ::MongoMapper.connection = @connection
          ::MongoMapper.database   = @database

          self
        end
      end
    end
  end
end
