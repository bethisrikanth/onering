require 'mongo_mapper'

module App
  module Model
    module Errors
      class ValidationError < Exception; end
    end

    module Utils

    # serialize to a Hash
      def to_h
        serializable_hash.reject{|k,v|
          ['_type'].include?(k)
        }
      end

      def to_h!
        serializable_hash
      end

    # populate the document from a Hash
      def from_h(hash, merge=true, autotype=false)
        raise "Cannot populate model: expected Hash, got #{hash.class.name}" unless hash.is_a?(Hash)

        if merge
        # build list of paths to fully replace
          unset_keys = Hash[hash.coalesce(nil, nil, '.').select{|k,v|
            k.include?('@')
          }].keys.collect{|k|
            k = k.split('.')
            i = k.index{|i| i[0].chr == '@' }

            (i ? k.first(i+1).join('.') : nil)
          }.compact.uniq

          newhash = to_h
        # delete existing keys that are to be replaced
        # rename incoming keys to exclude symbols
          unset_keys.each do |key|
            newhash.unset(key.delete('@'))
            hash.rekey(key, key.delete('@'))
          end

          newhash = newhash.deeper_merge!(hash, {:merge_hash_arrays => true})
        else
          newhash = hash
        end

      # automatically convert fields ending with _at or _on to Time
        newhash.each_recurse! do |k,v,p|
          case k
          when /_(?:at|on)$/i
            if v == 'now'
              Time.now
            else
              (Time.parse(v) rescue v)
            end
          else
            v
          end
        end

        newhash.each do |k,v|
          puts "SETTING #{k} = #{v.get('monitor').class.name} #{v.get('monitor')}" rescue nil
          send("#{k}=", v) rescue nil
        end

        self
      end

    # populate the document from a JSON string
      def from_json(json, merge=true, autotype=false)
        json = JSON.parse(json) if json.is_a?(String)
        json = [json] if json.is_a?(Hash)

        if json
          json.each do |j|
            from_h(j, merge, autotype)
          end
        end

        self
      end

    # save, but throw an error if not valid
      def safe_save
        save({
          :safe => true
        }) or raise Errors::ValidationError, errors.collect{|k,v| v }.join("; ")
      end

    # provide a difference between two documents (useful for audit history)
      def -(other)
        diff = (serializable_hash - other.serializable_hash)
      end


      alias_method :to_hash, :to_h
    end

    class Base
      include MongoMapper::Document
      include Utils

      class<<self
        alias :_mongo_find :find
        attr_accessor :query_limit
        attr_accessor :query_offset

        def find(id)
          q = self._mongo_find(id)
          q.limit(query_limit) if query_limit
          q.skip(query_offset) if query_offset
          q
        end

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

        def list(field, query=nil)
          rv = self.collection.distinct(field, query).compact.sort
          rv = rv[(query_offset.to_i)..(query_offset.to_i + (query_limit || rv.length))]
          rv
        end
      end
    end

    module Taggable
      def tag(value)
        [*value].each do |v|
          add_to_set({:tags => v})
        end
        safe_save
        self
      end
    end
  end
end
