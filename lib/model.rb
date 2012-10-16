require 'mongo_mapper'

module App
  module Model
    module Errors
      class ValidationError < Exception; end
    end

    module Utils
      def to_json
        serializable_hash.reject{|k,v|
          ['_type'].include?(k)
        }.to_json
      end

      def from_json(json)
        json = JSON.parse(json) if json.is_a?(String)

        json.each do |key, value|
          send("#{key}=", value) if value
        end
      end

      def safe_save
        save or raise Errors::ValidationError, errors.collect{|k,v| v }.join("; ")
      end

      def -(other)
        diff = (serializable_hash - other.serializable_hash)
      end
    end

    class Base
      include MongoMapper::Document
      include Utils

      class<<self
        def find_or_create(ids, init={})
          rv = find(ids)

          if not rv
            [*ids].each do |id|
              i = new({'id' => id})

              i.safe_save
            end

            rv = find(ids)
          end

          rv
        end
      end
    end

    class Embedded
      include MongoMapper::EmbeddedDocument
      include Utils
    end
  end
end