require 'controller'
require 'core/helpers/authentication'
require 'sinatra/session'

module App
  class Base < Controller
    include Helpers
    register Sinatra::Session

    configure do
      set :session_fail, '/login.html'
      set :session_secret, 'abc123zyx987'
    end

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

      get '/?' do
        output({
          :status => 'ok',
          :local_root => ENV['PROJECT_ROOT'],
          :environment => settings.environment,
          :backend_server_port => request.env['SERVER_PORT'],
          :backend_server_string => request.env['SERVER_SOFTWARE'],
          :remote_addr => (request.env['HTTP_X_REAL_IP'] || request.env['REMOTE_ADDR']),
          :request_url => request.url,
          :current_user => (@user ? @user.id : nil),
          :ssl => {
            :verified  => (request.env['HTTP_X_CLIENT_VERIFY'] == 'SUCCESS'),
            :subject =>   (request.env['HTTP_X_SSL_SUBJECT'] ? Hash[request.env['HTTP_X_SSL_SUBJECT'].to_s.sub(/^\//,'').split('/').collect{|i| i.split('=') }] : nil),
            :issuer  =>   (request.env['HTTP_X_SSL_ISSUER'] ? Hash[request.env['HTTP_X_SSL_ISSUER'].to_s.sub(/^\//,'').split('/').collect{|i| i.split('=') }] : nil)
          }
        })
      end
    end

  end
end
