require 'controller'
require 'assets/lib/helpers'
require 'assets/models/asset'
require 'assets/models/node_default'
require 'automation/models/job'

module App
  class Base < Controller
    include Helpers

    namespace '/api/devices' do
      namespace '/defaults' do
        get '/sync' do
          output(Automation::Job.urlquery('name/assets-sync').first.request())
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
              apply.each{|k,v| json['apply'].set(k, v) }
            end

            default = NodeDefault.new(json)
            default.save()

            default = NodeDefault.find(default.id)


            output((default || {}).to_hash)
          end
        end
      end


      # /devices/find
      # search for devices by fields
      %w{
        /find/?
        /find/*
      }.each do |r|
        get r do#ne
          qsq       = (params[:q] || params[:query] || '')
          q         = (!params[:splat] || params[:splat].empty? ? qsq : params[:splat].first.split('/').join('/')+(qsq ? '/'+qsq : ''))
          fields    = params[:only].split(',') unless params[:only].nil?
          page_size = (params[:max] || Config.get('global.api.default_max_results', Asset::DEFAULT_MAX_API_RESULTS)).to_i
          page_num  = (params[:page] || 1).to_i
          sort      = params[:sort].split(',').collect{|i|
            if i[0].chr == '-'
              { i[1..-1].to_sym => :desc }
            else
              { i.to_sym        => :asc}
            end
          } if params[:sort]

          rv = Asset.urlquery(q, {
            :size         => page_size,
            :from         => (page_size * (page_num-1)),
            :sort         => sort
          }.compact, {
            :raw => true
          })

          total = rv.get('hits.total', 0)
          if total > 0

            headers({
              'X-Onering-Results-Count'       => total.to_s,
              'X-Onering-Results-Page-Size'   => ([total, page_size].min).to_s,
              'X-Onering-Results-Page-Number' => page_num.to_s,
              'X-Onering-Results-Page-Count'  => (total / page_size).ceil.to_s
            })
            output(filter_hash(rv.get('hits.hits', []).collect{|i|
              Asset.new(i['fields'].merge({
                :id   => i['_id'],
                :type => i['_type']
              })).to_hash()
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

          Asset.mappings.get('properties',{}).each_recurse({
            :intermediate => true
          }) do |k,v,p|
            if v.is_a?(Hash) and v['type'].is_a?(String)
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
          output(Asset.list(params[:splat].first.split('/'), params[:q]))
        end
      end


    # /devices/summary
      %w{
        /summary/by-:field/?
        /summary/by-:field/*/?
      }.each do |r|
        get r do#ne
          q = (params[:where] || params[:q])
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

          if params[:id]
            id = params[:id]
          else
            json = MultiJson.load(data)
            id = json['id']
          end

          if params[:direct].to_bool === true
            json = MultiJson.load(data) unless json
            json['collected_at'] = Time.now if json.delete('inventory') === true
            device = Asset.find(id)
            return 404 unless device
            device.from_hash(json)
            device.save()
            output(device)
          else
            job = Automation::Job.urlquery('name/assets-update').first
            return 503 unless job

            output(job.request({
              :data       => data,
              :parameters => {
                :nodes => [id]
              }
            }))
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

        output(device)
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
        tags.each{|t| device.tags.push_uniq(t) }
        device.save({},{
          :replication => :sync
        })
        output(device)
      end


      get '/:id/untag/*' do
        tags = params[:splat].first.split(/\W/)
        device = Asset.find(params[:id])
        tags.each{|t| device.tags.delete(t) }
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
          device.status = params[:status]
        end

        device.save({},{
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
