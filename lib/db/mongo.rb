
module App
  module Database
    class Mongo
      require 'mongo'
      require 'mongo_mapper'

      class<<self
        def load(name, config)
          logger = Logger.new(File.join(ENV['PROJECT_ROOT'], "mongo-#{name}.log"))
          @database = name
          @connection = ::Mongo::Connection.new(
            (config['host'] || 'localhost'),
            (config['port'] || 27017).to_i,
            :logger => logger,
            :safe => config['safe'].to_s.to_bool
          )

          ::MongoMapper.connection = @connection
          ::MongoMapper.database   = @database

          self
        end
      end
    end
  end
end