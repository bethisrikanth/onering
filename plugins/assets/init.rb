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

require 'set'
require 'controller'
require 'ipaddr'
require 'assets/lib/helpers'
require 'assets/models/asset'
require 'assets/models/node_default'
require 'assets/models/registered_address'

module App
  class Base < Controller
    include Helpers

    namespace '/api/devices' do
      namespace '/defaults' do
        get '/sync' do
          queued = Automation::Tasks::Task.run('assets/sync')
          return 500 unless queued
          return 200
        end

        get '/groups' do
          output(NodeDefault.list('group')+['Ungrouped'])
        end

        get '/list' do
          defaults = NodeDefault.all.collect{|i|
            i = i.to_hash()
            i['apply'] = i['apply'].coalesce(nil,nil,'.')
            i
          }

          defaults = defaults.group_by{|i| i['group'] }

          unless defaults[nil].nil?
            defaults['Ungrouped'] = defaults[nil]
            defaults.delete(nil)
          end

          output(defaults)
        end

        get '/:id' do
          default = NodeDefault.find(params[:id])
          return 404 unless default
          output(default.to_hash)
        end

        delete '/:id' do
          default = NodeDefault.find(params[:id])
          return 404 unless default
          default.destroy()
          200
        end

        %w{
          /?
          /:id
        }.each do |r|
          post r do
            default = (params[:id] ? NodeDefault.find(params[:id]) : NodeDefault.new())
            return 404 unless default
            rv = []

            json = MultiJson.load(request.env['rack.input'].read)
            return 400 unless json.is_a?(Hash)

            if json['apply']
              apply = json['apply'].clone
              json['apply'] = {}
              apply.each{|k,v| json['apply'].rset(k, v.autotype()) }
            end

            default = NodeDefault.new(json)
            default.save()

            default = NodeDefault.find(default.id)


            output((default || {}).to_hash)
          end
        end
      end


      namespace '/ipam' do
        get '/list/*/?' do
          fields = params[:splat].first.split('/')
          addresses = RegisteredAddress.list(fields, params[:q])

          output(addresses)
        end

        get '/all/?' do
          output(RegisteredAddress.all.collect{|i|
            i.to_hash()
          })
        end

        get '/find/?' do
          addresses = RegisteredAddress.urlquery(params[:q], @queryparams)
          output(addresses.collect{|i|
            i.to_hash()
          })
        end

        get '/pools/list' do
          output(RegisteredAddress.list(:pool).compact.sort.collect{|i|
            {
              :name         => i,
              :title        => App::Config.get("assets.ipam.pools.#{i}.title"),
              :description  => App::Config.get("assets.ipam.pools.#{i}.description"),              
            }
          })
        end

        get '/pools/:pool/?' do
          addresses = RegisteredAddress.urlquery("pool/#{params[:pool]}")
          return 404 if addresses.empty?

          output({
            :pool         => params[:pool],
            :title        => App::Config.get("assets.ipam.pools.#{params[:pool]}.title"),
            :description  => App::Config.get("assets.ipam.pools.#{params[:pool]}.description"),
            :addresses    => addresses.collect{|i|
              i = i.to_hash()
              i.delete('id')
              i.delete('type')
              i
            }.sort{|a,b|
              IPAddr.new(a.get(:value)) <=> IPAddr.new(b.get(:value))
            },
            :count        => {
              :total      => addresses.length,
              :claimed    => addresses.select{|i| i.claimed? }.length,
              :reserved   => addresses.select{|i| i.reserved? }.length,
              :assignable => addresses.select{|i| i.available? }.length,
            }
          })
        end

        get '/address/claim/:pool/?' do
          address = RegisteredAddress.next_unclaimed_address(params[:pool], params[:asset], {
            :retries   => params[:retries],
            :selection => params[:selection]
          })

          halt 404 if address.nil?
          output(address.to_hash)
        end

        get '/address/release/:ip' do
          address = RegisteredAddress.urlquery("str:value/is:#{params[:ip]}")
          return 404 if address.empty?
          address = address.first
          address.release()
          address.save({
            :replication => :sync
          })

          return 204
        end
      end


      # /devices/find
      # search for devices by fields
      %w{
        /find/?
        /find/*
      }.each do |r|
        get r do#ne
          qsq       = (params[:q] || params[:query]).autotype()
          q         = (!params[:splat] || params[:splat].empty? ? qsq : params[:splat].first.split('/').join('/')+(qsq ? '/'+qsq : ''))
          fields    = params[:only].split(',') unless params[:only].nil?

          rv = Asset.urlquery(q, @queryparams, {
            :raw => true
          })

          total = rv.get('hits.total', 0)
          if total > 0
            paginate_headers(total)

            output(filter_hash(rv.get('hits.hits', []).collect{|i|
              data = {
                :id   => i['_id'],
                :type => i['_type']
              }

              i['fields'].each{|k,v|
                data.set(k,v)
              }

              Asset.new(data).to_hash()

            }, Asset.field_prefix))
          else
            output([])
          end
        end
      end

    # list all fields from all documents in the index
      namespace '/schema' do
        get '/fields' do
          rv = []

          Asset.all_mappings.get('asset.properties',{}).each_recurse({
            :intermediate => true
          }) do |k,v,p|
            if v.is_a?(Hash) and v['type'].is_a?(String) and p[-2] != 'fields'
              rv << p.join('.').gsub(/(?:^device\.|^asset\.|properties\.|\.properties)/,'')
            end
          end

          output(rv.sort)
        end
      end


    # show devices that haven't been updated
      %w{
        /list/stale/?
        /list/stale/:age
      }.each do |r|
        get r do#ne
          output(Asset.list('id', {
            'collected_at' => {
              '$lte' => (params[:age] || 4).to_i.hours.ago
            }
          }))
        end
      end

    # /devices/list
    # list field values
      %w{
        /list/*/?
        /list/*
      }.each do |r|
        get r do#ne
          output(Asset.list(params[:splat].first.split('/'), params[:q].autotype()))
        end
      end


    # /devices/summary
      %w{
        /summary/by-:field/?
        /summary/by-:field/*/?
      }.each do |r|
        get r do#ne
          q = (params[:where] || params[:q]).autotype()
          rv = Asset.summarize(params[:field], (params[:splat].first.split('/').reverse rescue []), q)
          output(rv)
        end
      end


    # device by id
      get '/:id' do
        asset = Asset.find(params[:id])
        return 404 if not asset
        d = asset.to_hash

        d[:children] = asset.children.collect{|i|
          filter_hash(i.to_hash, :properties)
        } if params[:children]

        output(filter_hash(d, :properties))
      end

      delete '/:id' do
        asset = Asset.find(params[:id])
        return 404 if not asset
        asset.destroy()
        200
      end


    # device pane configurations
      get '/:id/panes' do
        allowed_to? :get_asset, params[:id]
        device = Asset.find(params[:id])
        return 404 unless device

        rv = [{
          :id         => 'system',
          :template   => 'node-pane-system'
        },{
          :id         => 'config',
          :title      => 'Configuration',
          :template   => 'node-pane-config'
        },{
          :id       => 'apps',
          :title    => 'Applications',
          :template => 'node-pane-apps'
        },{
          :id         => 'provision',
          :title      => 'Provisioning',
          :template   => 'node-pane-provision'
        }]

        if ['allocatable', 'installing'].include?(device.status.to_s)
          rv[rv.index{|i| i[:id] == 'provision' }][:default] = true
          rv[rv.index{|i| i[:id] == 'apps'      }][:hidden] = true
        else
          rv[rv.index{|i| i[:id] == 'system' }][:default] = true
        end

        output(rv)
      end

    # arbitrary configuration trees
      get '/:id/config/?*' do
        allowed_to? :get_asset, params[:id]
        device = Asset.find(params[:id])
        return 404 unless device

        rv = device.properties.get(['config']+params[:splat].first.split('/'))
        return 404 if rv.nil? or (rv.respond_to?(:empty?) and rv.empty?)

        output(rv)
      end


      get '/:id/parent' do
        allowed_to? :get_asset, params[:id]
        device = Asset.find(params[:id])
        return 404 unless device and device.parent_id and device.parent
        output(filter_hash(device.parent.to_hash, :properties))
      end

      get '/:id/children' do
        allowed_to? :get_asset, params[:id]
        device = Asset.find(params[:id])
        return 404 unless device
        output(device.children.collect{|i|
          allowed_to?(:get_asset, i.id) rescue next
          filter_hash(i.to_hash, :properties)
        })
      end


      get '/:id/defaults' do
        allowed_to? :get_asset, params[:id]
        device = Asset.find(params[:id])
        return 404 unless device

        output(device.defaults.collect{|i|
          i.to_hash
        })
      end

      get '/:id/decomission' do
        #allowed_to? :decomission_asset, params[:id]
        device = Asset.find(params[:id])
        return 404 unless device
        rv = {
          :account_removed  => false,
          :keys_reset       => [],
          :tasks_dispatched => []
        }

      # remove machine account
        account = User.find(device.id)
        if account
          account.destroy()
          rv[:account_removed] = true
        end

      # cleanup keys
        Config.get('assets.decomission.reset_properties', []).each do |property, value|
          device.set(property, value)
          rv[:keys_reset] << property
        end

      # save device
        device.save()

      # determine the list of cleanup tasks
        tasks = Set.new()

        Config.get('assets.decomission.tasks', {}).each do |key, match|
          next if key == 'default'
          next unless match.is_a?(Hash)

        # only run tasks for matching criteria
          match.each do |value, list|
            next unless list.is_a?(Array)

            if [*device.get(key,[])].include?(value)
              list.each do |i|
                tasks << i
              end
            end
          end
        end

        Config.get('assets.decomission.tasks.default', []).each do |task|
          tasks << task
        end

      # schedule cleanup tasks
        tasks.each do |task|
          Automation::Tasks::Task.run_critical(task, device.id, device.to_hash())
          rv[:tasks_dispatched] << i
        end

        output(rv)
      end

    # child management operations
      get '/:id/children/:action/?*/?' do
        allowed_to? :update_asset, params[:id]
        device = Asset.find(params[:id])
        action = params[:action].to_s.downcase.to_sym
        child_ids = params[:splat].first.split('/')
        return 404 unless device


      # set operation works on all children
        if action == :set or action == :unset
          children = Asset.search({
            :parent_id => params[:id]
          }).to_a

        # an empty existing set means we're just going to take the incoming set as gospel
          if children.empty? and action == :set
            children = Asset.find(child_ids)
          end
        else
      # add/remove can operate exclusively on named child IDs
          children = Asset.find(child_ids)
        end

        children.each do |child|
          allowed_to?(:update_asset, child.id) rescue next

          case action
          when :add    then child.parent_id = params[:id]
          when :remove, :unset then child.parent_id = nil
          when :set    then
          # if the current child is in the set, set its parent
            if child_ids.include?(child.id)
              child.parent_id = params[:id]
            else
              child.parent_id = nil
            end
          end

          child.save
        end

        output(device)
      end

      %w{
        /?
        /:id
      }.each do |route|
        post route do
          data = request.env['rack.input'].read
          json = MultiJson.load(data)

          if params[:id]
            id = params[:id]
          else
            id = json['id']
          end

          if params[:direct].to_bool === true
            json['collected_at'] = Time.now if json.delete('inventory') === true
            device = Asset.find(id)
            return 404 unless device
            device.from_hash(json)
            device.save()
            output(device)
          else
            queued = Automation::Tasks::Task.run('assets/update', json)
            return 500 unless queued
            return 200
          end
        end
      end

      %w{
        /:id/notes/?
        /:id/notes/:note_id/?
      }.each do |route|
        post route do
          device = Asset.find(params[:id])
          return 404 if not device

          if device.add_note(request.env['rack.input'].read, @user.id)
            device.save()
          else
            400
          end

          200
        end

        delete route do
          device = Asset.find(params[:id])
          return 404 if not device

          if device.properties and device.properties['notes']
            params[:note_id] = params[:note_id].to_i
            note = device.properties['notes'][params[:note_id].to_i]

            unless note.nil?
              allowed_to? :remove_asset_note, device.properties['notes'][params[:note_id]]

              device.properties['notes'].delete_at(params[:note_id])
              device.properties.delete('notes') if device.properties['notes'].empty?
              device.save()
            end
          end

          200
        end
      end


    # set devices properties
      get "/:id/set/:key/:value" do
        device = Asset.find(params[:id])
        return 404 if not device

        device.properties.set(params[:key], params[:value].convert_to(params[:coerce] || :auto))

        device.save({},{
          :replication => :sync
        })

        output(device)
      end

      get "/:id/unset/:key" do
        device = Asset.find(params[:id])
        return 404 if not device

        device.properties.delete(params[:key])

        device.save({},{
          :replication => :sync
        })

        output(device.to_hash())
      end

    # get device property
      get '/:id/get/*' do
        device = Asset.find(params[:id])
        return 404 if not device
        rv = []
        params[:splat].first.split('/').each do |key|
          rv << device.properties.get(key)
        end

        if rv.length == 1
          output(rv.first)
        else
          output(rv)
        end
      end

    # vector operations
      get '/:id/push/:key/:value/?' do
        device = Asset.find(params[:id])
        return 404 if not device

        device.push(params[:key], params[:value], params[:coerce])
        device.save({},{
          :replication => :sync
        })
        output(device)
      end

      get '/:id/pop/:key/?' do
        device = Asset.find(params[:id])
        return 404 if not device

        rv = device.pop(params[:key])
        device.save({},{
          :replication => :sync
        })
        output(rv)
      end


    # tagging
    # these are GETs because this should be a trivial user action
      get '/:id/tag/*' do
        tags = params[:splat].first.split(/\W/)
        device = Asset.find(params[:id])
        device.tags = (device.tags + tags).uniq.sort

        device.save({},{
          :replication => :sync
        })
        output(device)
      end


      get '/:id/untag/*' do
        tags = params[:splat].first.split(/\W/)
        device = Asset.find(params[:id])
        device.tags = (device.tags - tags)

        device.save({},{
          :replication => :sync
        })
        output(device)
      end


    # status
    # set the status of a device
      get '/:id/status/:status' do
        device = Asset.find(params[:id])
        return 404 if not device

        case params[:status]
        when 'unknown', 'clear', 'null'
          device.status = nil
        else
        # either the current status is not immutable or it is but we're forcing the issue...
          if not Asset.states(true).include?(device.status) or params[:force] == true
            device.status = params[:status]
          end
        end

        device.save({
          :reload => true
        },{
          :replication => :sync
        })

        output(device)
      end

    # maintenance_status
    # set the maintenance_status of a device
      get '/:id/maintenance/:status' do
        device = Asset.find(params[:id])
        return 404 if not device
        if params[:status] == 'healthy'
          device.maintenance_status = nil
        else
          device.maintenance_status = params[:status]
        end

        device.save({},{
          :replication => :sync
        })

        output(device.to_hash)
      end
    end
  end
end
