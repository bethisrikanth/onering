require 'assets/models/asset'

module Automation
  module Tasks
    module Assets
      class Update < Task
        def self.perform(node_object, sync=false)
          node = Asset.find(node_object['id'])

          if node.nil?
            info("Node #{node_object['id']} does not exist, creating...")
            node = Asset.new()
          else
            if sync === true
              node.save()
              return true
            end
          end

          warn("Node object 'properties' field is empty, possible error in inventory") if node_object.get(:properties,{}).empty?

        #
        # handle "replacement merge" operator (@)
        # wherein fields in the incoming data are prefixed with an "@"
        # symbol to denote that all existing data under that key should first
        # be removed before merging the incoming data
        #
        # this handles cases like deeply-nested objects in arrays that could
        # accumulate stale entries
        #
          inventory = node.to_hash()
          unset_keys = Hash[node_object.coalesce(nil, nil, '.').select{|k,v|
            k.include?('@')
          }].keys.collect{|k|
            k = k.split('.')
            i = k.index{|i| i[0].chr == '@' }

            (i ? k.first(i+1).join('.') : nil)
          }.compact.uniq


        # delete existing keys that are to be replaced
        # rename incoming keys to exclude symbols
          unset_keys.each do |key|
            inventory.unset(key.delete('@'))
            node_object.rekey(key, key.delete('@'))
          end

        # merge the new into the old
          inventory = inventory.deeper_merge!(node_object, {
            :merge_hash_arrays => true
          })

        # set collected_at time
          if inventory['inventory'].to_bool === true
            inventory.delete('inventory')
            inventory['collected_at'] = Time.now
          end

        # load processed object
          node.from_hash(inventory)

        # save
          if node.save()
            info("Saved node #{node.id}")
          else
            error("Failed to save #{node.id}")
          end
        end

        def self.before_perform(*args)
          node_object = args.first

          fail("Malformed node object: expected Hash, got #{node_object.class.name}") unless node_object.is_a?(Hash)
          fail("Not processing empty node object") if node_object.empty?
          fail("Node object is missing the 'id' field, cannot save") if node_object['id'].nil?

          info("#{args[1]=== true ? 'Syncing' : 'Updating'} node #{node_object['id']}")
        end
      end
    end
  end
end
