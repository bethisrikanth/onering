require 'controller'
require 'core/helpers/authentication'

module App
  class Base < Controller
    before do
      if Config.get('global.force_ssl')
        port = (request.port == 80 ? '' : ":#{request.port}")
        redirect "https://#{request.host}#{port}", 301
      end

      unless Config.get('global.authentication.disable') then
        @user = nil
        auth = Rack::Auth::Basic::Request.new(request.env)

        unless auth.provided? then
          response['WWW-Authenticate'] = "Basic realm=\"#{Config.get('global.authentication.realm') || 'HTTP Authentication'}\""
          throw :halt, 401
        end

        throw :halt, 400 unless auth.basic?

      # this will become the correct class using MM Single-collection inheritance
        user = User.find(auth.username)

      # if user found...
        if user
        # and user/pass were good...
          if user.authenticate!({
            :username => auth.username,
            :password => auth.credentials[1]
          })
            user.logged_in_at = Time.now
            user.safe_save
            @user = user

          else
            throw :halt, 401
          end
        else
          throw :halt, 401
        end
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
          :remote_addr => request.env['REMOTE_ADDR'],
          :request_url => request.url,
          :current_user => (@user ? @user.id : nil)
        })
      end
    end

  end
end
