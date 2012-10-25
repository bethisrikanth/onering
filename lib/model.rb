require 'mongo_mapper'

module App
  module Model
    module Errors
      class ValidationError < Exception; end
    end

    module Utils
      def to_h
        serializable_hash.reject{|k,v|
          ['_type'].include?(k)
        }
      end

      def to_json
        to_h.to_json
      end


      def from_h(hash, merge=true)
        current = to_h
        current.deeper_merge!(hash, {:merge_hash_arrays => true})
        
        current.each do |k,v|
          send("#{k}=", v)
        end

        self
      end

      def from_json(json, merge=true)
        json = JSON.parse(json) if json.is_a?(String)
        json = [json] if json.is_a?(Hash)

        json.each do |j|
          from_h(j, merge)
        end
        self
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

        def summarize(group_by, properties=[], options=nil)
          c = [{
            '$group' => {
              :_id => "$#{group_by}",
              :total => {'$sum' => 1},
            }
          }]

          # if not properties.empty?
          #   c[:properties] = {}
          #   properties.each{|p| c[:properties].set("$#{p}", {
          #     '$sum' => 1
          #   })}
          # end

          collection.aggregate(c)
        end
      end
    end

    class Embedded
      include MongoMapper::EmbeddedDocument
      include Utils
    end
  end
end