
module App
  module Database
    class Mongo
      require 'mongo'
      require 'mongo_mapper'

      class<<self
        def load(name, config)
          logger = Logger.new(File.join(App::Base::PROJECT_ROOT, "mongo-#{name}.log"))
          @database = name
          @connection = ::Mongo::Connection.new(
            (config['host'] || 'localhost'), 
            (config['port'] || 27017).to_i,
            :logger => logger
          )

          ::MongoMapper.connection = @connection
          ::MongoMapper.database   = @database
          
          self
        end
      end
    end
  end
end