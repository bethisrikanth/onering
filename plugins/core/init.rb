require 'controller'
require 'sinatra/session'
require 'core/models/navigation'

module App
  class Base < Controller
    before do
    # force SSL redirect
      if Config.get('global.force_ssl')
        port = (request.port == 80 ? '' : ":#{request.port}")
        redirect "https://#{request.host}#{port}", 301
      end
    end

    get '/' do
      index = File.join(settings.public_folder, 'index.html')
      File.read(index) if File.exists?(index)
    end

    if settings.environment == 'development'
      require 'rack/webconsole'
      use Rack::Webconsole

      get '/console' do
        Rack::Webconsole.inject_jquery = true

        content_type 'text/html'
        "<html><body></body></html>"
      end
    end

  # anything in the /api namespace will be JSON (for now, other types pending)
    namespace '/api' do
      before do
        content_type 'application/json'
      end

      helpers do
        def get_current_git_head()
          rv = Config.get('repo', {})

        # if the config is undefined, populate it
          if rv.empty?
            IO.popen("cd #{ENV['PROJECT_ROOT']} && git log -1 HEAD").lines.each do |line|
              case line.strip.chomp
              when /^commit\s+([0-9a-f]+)$/
                rv[:commit] = $1

              when /^Author:\s+(.*)/
                rv[:author] = $1

              when /^Date:\s+(.*)/
                rv[:date] = $1

              end
            end

          # determine branch
            rv[:branch] = (IO.popen("cd #{ENV['PROJECT_ROOT']} && git symbolic-ref -q HEAD").read.strip.chomp.split('/').last rescue nil)

          # get short revision
            rv[:id] = (IO.popen("cd #{ENV['PROJECT_ROOT']} && git rev-parse --short HEAD").read.strip.chomp rescue nil)

          # normalize the date
            rv[:date] = Time.parse(rv[:date]) unless rv[:date].nil?

            Config.set('repo', rv)
          end

          return nil if rv.empty?
          return rv
        end
      end

      get '/?' do
        output({
          :status => 'ok',
          :local_root => ENV['PROJECT_ROOT'],
          :environment => settings.environment,
          :repository => get_current_git_head(),
          :backend => {
            :hostname => (%x{hostname -f}.strip.chomp rescue nil),
            :port => (request.env['HTTP_X_PROXY_PORT'] || request.env['SERVER_PORT']).to_i,
            :identity => request.env['SERVER_SOFTWARE']
          },
          :database => {
            :status => {
              :current_node => App::Model::Elasticsearch.status(),
              :cluster      => App::Model::Elasticsearch.cluster_status()
            }
          },
          :remote_addr => (request.env['HTTP_X_REAL_IP'] || request.env['REMOTE_ADDR']),
          :request_url => request.url,
          :ssl => {
            :verified  => (request.env['HTTP_X_CLIENT_VERIFY'] == 'SUCCESS'),
            :subject =>   (request.env['HTTP_X_SSL_SUBJECT'] ? Hash[request.env['HTTP_X_SSL_SUBJECT'].to_s.sub(/^\//,'').split('/').collect{|i| i.split('=') }] : nil),
            :issuer  =>   (request.env['HTTP_X_SSL_ISSUER'] ? Hash[request.env['HTTP_X_SSL_ISSUER'].to_s.sub(/^\//,'').split('/').collect{|i| i.split('=') }] : nil)
          }
        })
      end

      get '/navigation/?' do
        #output(Navigation.all.collect{|i| i.to_h }.first)
        output({})
      end

      get '/navigation/filters' do
        rv = Config.get('global.navigation.filters',[])

        output(rv.collect{|i|
          i['values'] = Asset.list(i['field']).collect{|j|
            {
              :value => j,
              :icon  => i['icons'][i['icons'].keys.select{|k| j =~ Regexp.new(k) }.first]
            }.compact
          }
          i
        })
      end


      namespace '/config' do
        get '/?' do
          #allowed_to? :read_config
          output(App::Config.to_hash())
        end

        post '/?' do
          #allowed_to? :update_config
          data = MultiJson.load(request.env['rack.input'].read)
          config = Configuration.create(data)
          output(config.to_hash())
        end

        get '/debug/?' do
          output(App::Config.registrations())
        end

        get '/all/?' do
          #allowed_to? :read_config

          output(Configuration.all.collect{|i|
            i.to_hash()
          })
        end

        get '/find/?' do
          #allowed_to? :read_config
          halt 400 unless params[:q]
          config = Configuration.urlquery(params[:q], @queryparams)

          output(config.collect{|i|
            i.to_hash()
          })
        end

        get '/:id/?' do
          #allowed_to? :read_config, params[:id]
          config = Configuration.find(params[:id])
          halt 404 unless config
          output(config.to_hash())
        end

        post '/:id/?' do
          #allowed_to? :update_config, params[:id]

          config = Configuration.find(params[:id])
          halt 404 unless config

          data = MultiJson.load(request.env['rack.input'].read)
          config.update(data)
          config.save()

          output(config.to_hash())
        end

        delete '/:id/?' do
          #allowed_to? :delete_config, params[:id]

          config = Configuration.find(params[:id])
          halt 404 unless config

          config.destroy()
          200
        end
      end
    end

  end
end
