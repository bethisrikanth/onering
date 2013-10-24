require 'assets/models/asset'

module Automation
  module Tasks
    module Assets
      class Update < Base
        def run(request)
          rv = []
          nodes = []

          if opt(:query)
            nodes += Asset.urlsearch(opt(:query)).to_a if opt(:query)
            log("Updating #{nodes.length} nodes from query: #{opt(:query)}", :info)

          elsif opt(:nodes)
            n = opt(:nodes).flatten
            nodes += Asset.find([*n]).to_a

            log("Updating #{nodes.length} nodes explicitly named by ID", :info) unless nodes.empty?
            log("Nodes: #{nodes.collect{|i| i.id }.join(', ')}", :debug) unless nodes.empty?

            inserts = (n - nodes.collect{|i| i.id })

            if not inserts.empty?
              log("Inserting #{inserts.length} nodes explicitly named by ID", :info)

              inserts.each do |id|
                nodes << Asset.new({
                  :id => id
                })
              end
            end
          end

          raise abort("No nodes specified") if nodes.empty?

          nodes.each do |node|
            fail("Data is required for the update action") if @data.nil?

            begin
              if @data.is_a?(String)
                begin
                  @data = MultiJson.load(@data)
                rescue MultiJson::LoadError => e
                  log("Error loading JSON: #{e.message}", :warn)
                  log("Data dump:\n#{@data.inspect}", :debug)
                  raise e
                end
              end

              if @data.is_a?(Hash)
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
                unset_keys = Hash[@data.coalesce(nil, nil, '.').select{|k,v|
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
                  @data.rekey(key, key.delete('@'))
                end

                inventory = inventory.deeper_merge!(@data, {
                  :merge_hash_arrays => true
                })

                if inventory['inventory'].to_bool === true
                  inventory.delete('inventory')
                  inventory['collected_at'] = Time.now
                end

                node.from_hash(inventory)

              else
                fail("Data must be a JSON string or hash, got: #{@data.class.name}")
              end

              node.save()
              rv << node.to_hash.get(opt(:field, 'id'))
            rescue Exception => e
              log("Error updating node #{node.id}: #{e.class.name} - #{e.message}", :error)
              e.backtrace.each do |b|
                log("  #{b}", :debug)
              end

              next
            end
          end

          return rv
        end
      end
    end
  end
end
