require 'openssl'
require 'digest/md5'
require 'auth/helpers/helpers'
require 'sinatra/session'

# user types
require 'auth/models/pam_user'
require 'auth/models/device_user'

require 'auth/models/group'
require 'auth/models/capability'

module App
  class Base < Controller
    include Helpers
    register Sinatra::Session

    configure do
      set :session_fail, '/login.html'

    # get session secret from config
    # TODO: should this rotate at all?
      set :session_secret, File.read(File.join(ENV['PROJECT_ROOT'], 'config', 'session.key'))
    end

    helpers do
      def user_authenticate(user, password)
        if user.authenticate!({
          :password => password
        })
          user.logged_in_at = Time.now
          user.save()

          return user
        end

        return nil
      end
    end

  # session based authentication
    before do
      unless anonymous?(request.path)
        @bootstrapUser = false

      # attempt SSL client key auth (if present)
        if ssl_verified?
          subject = ssl_hash(:subject)
          issuer =  ssl_hash(:issuer)

        # subject and issuer are required
          if subject and issuer
          # make sure issuer Organization's match
            #subject.select{|i| i[0] == 'O'} === issuer.select{|i| i[0] == 'O'}

          # get OU, CN
            ou = (subject.select{|i| i[0] == 'OU'}.first.last) rescue nil
            cn = (subject.select{|i| i[0] == 'CN'}.first.last) rescue nil

          # if SSL subject is .../OU=System/CN=Validation
            if cn
              if ou == 'System'
                if cn == 'Validation'
                  @bootstrapUser = true
                else
                  halt 403, "Invalid system certificate presented"
                end
              else
              # get user named by CN
                @user = User.find_by_id(cn) rescue nil
              end
            else
              halt 403, "Invalid client certificate presented"
            end

          # TODO
          # ensure the key submitted matches the like-named key for this user
          # does this mean i have to store the private key and sign this cert to "properly" verify it?
          #
          end
        end

      # if SSL client key was not present...
        if not @user and not @bootstrapUser
          mechanism = (request.env['HTTP_X_AUTH_MECHANISM'] || (params[:token].nil? ? nil : 'token')).to_s.downcase

          case mechanism
          when 'basic'
            auth = Rack::Auth::Basic::Request.new(request.env)

            if auth.provided? and auth.basic? and auth.credentials
              user = User.find_by_id(auth.credentials.first)
              halt 401 if user.nil?

              user = user_authenticate(user, auth.credentials.last)
              halt 401 if user.nil?

              @user = user
            else
              response['WWW-Authenticate'] = "Basic realm=\"Onering on #{ENV['SERVER_NAME']}\""
              halt 401
            end

          when 'token'
            if params[:token] =~ /[0-9a-f]{32,64}/
              user = User.urlquery("tokens.key/#{params[:token]}").to_a

              if user.length == 1
                @user = user.first
              else
                halt 401, "Invalid API token specified"
              end
            else
              halt 401, "Invalid API token specified"
            end


          else
            session_start!
            session! unless session?
            @user = User.find_by_id(session[:user]) if session[:user]

          end
        end

        halt 401, "Invalid authentication request" unless @user or @bootstrapUser
      end
    end

    namespace '/api' do
    # user management
      namespace '/users' do
      # get user list
        get '/list' do
          allowed_to? :list_users
          output(User.all({
            :_type.ne => Config.get('global.authentication.machine_user_type', 'DeviceUser')
          }).collect{|i| i.to_hash })
        end

        get '/list/machines' do
          allowed_to? :list_machines
          output(User.all({
            :_type => Config.get('global.authentication.machine_user_type', 'DeviceUser')
          }).collect{|i| {
            :id         => i.id,
            :created_at => i.created_at,
            :updated_at => i.updated_at
          } })
        end

      # get user types list
        get '/list/types' do
          allowed_to? :list_users
          output(User.list(:_type).collect{|i| i.gsub('User','').downcase }.compact.reject{|i| i.empty? })
        end

      # perform session login
        post '/login' do
          json = JSON.load(request.env['rack.input'].read)

          if json
            user = User.find_by_id(json['username'])
            halt 401, 'Invalid credentials' unless user

            user = user_authenticate(user, json['password'])

          # and user/pass were good...
            if user.nil?
              halt 401, 'Invalid credentials'
            else
              @user = session[:user] = user.id
            end
          else
            halt 400
          end

          200
        end

        get '/logout' do
          session_end!
          200
        end

      # get user
        get '/:id' do
          id = (params[:id] == 'current' ? @user.id : params[:id])

          allowed_to? :get_user, id

          return 404 if id.nil?
          user = User.find_by_id(id)
          return 404 unless user
          output(user.to_hash)
        end

      # update user
        post '/:id' do
          id = (params[:id] == 'current' ? @user.id : params[:id])

          allowed_to? :update_user, id

          json = JSON.load(request.env['rack.input'].read)

          if json
          # remove certain fields
            json.delete_if{|k,v|
              k =~ /(?:^_?id$|_at$)/
            }

            user = User.find_or_create(id)
            user.from_json(json).save()
            user.reload

            output(user)
          else
            raise "Invalid JSON submitted"
          end
        end

      # delete user
        delete '/:id' do
          allowed_to? :delete_user

          User.destroy(params[:id])
          200
        end

      # set user gravatar image
        get '/:id/gravatar' do
          id = (params[:id] == 'current' ? @user.id : params[:id])
          allowed_to? :get_user, id

          user = User.find_by_id(id)
          return 404 unless user

          email = (user.email || user.id+'@'+Config.get('global.email.default_domain'))
          gravatar_id = user.get('gravatar_id')
          gravatar_id = Digest::MD5.hexdigest(email.strip) unless gravatar_id

          if gravatar_id
            qs = request.env['rack.request.query_hash'].collect{|k,v| "#{k}=#{v}" }.join('&')
            redirect ["http://www.gravatar.com/avatar/#{gravatar_id}", qs].compact.join('?')
          else
            halt 404, "Unable to calculate Gravatar ID"
          end
        end

      # test for the presence of the given key
        head '/:id/keys/:name' do
          id = (params[:id] == 'current' ? (@user ? @user.id : params[:id]) : params[:id])
          user = User.find_by_id(id)
          return 404 unless user

          halt 200 if user.client_keys.keys.include?(params[:name])
          halt 404
        end

      # generate a new API token
        get '/:id/tokens/:name' do
          id = (params[:id] == 'current' ? (@user ? @user.id : params[:id]) : params[:id])
          user = User.find_by_id(id)
          return 404 unless user

          content_type 'text/plain'
          user.token(params[:name])
        end


        delete '/:id/tokens/:name' do
          id = (params[:id] == 'current' ? (@user ? @user.id : params[:id]) : params[:id])
          user = User.find_by_id(id)
          return 404 unless user

          user.tokens.delete_if{|i| i['name'] == params[:name] }
          user.save()

          200
        end

      # generate a new client key for this user
        get '/:id/keys/:name' do
          id = (params[:id] == 'current' ? (@user ? @user.id : params[:id]) : params[:id])

        # this is also where pre-validated devices go to retrieve their API key
          if @bootstrapUser === true and not id === 'current'
            DeviceUser.find_or_create(id, {})
          end


          #allowed_to? :generate_api_key, id

          user = User.find_by_id(id)
          return 404 unless user

          if not user.client_keys[params[:name]]
            keyfile = Config.get!('global.authentication.methods.ssl.ca.key')
            crtfile = Config.get!('global.authentication.methods.ssl.ca.cert')
            client_subject = "/C=US/O=Outbrain/OU=Onering/OU=Users/CN=#{user.id}"

            halt 500, "OpenSSL is required to generate keys" unless defined?(OpenSSL)
            halt 500, "Cannot find server CA key" unless File.readable?(keyfile)
            halt 500, "Cannot find server CA certificate" unless File.readable?(crtfile)

          # server cert details
            cacert = OpenSSL::X509::Certificate.new(File.read(crtfile))

          # new client pkey
            key = OpenSSL::PKey::RSA.new(File.read(keyfile))

          # fill in new cert details
            client_cert = OpenSSL::X509::Certificate.new
            client_cert.subject = OpenSSL::X509::Name.parse(client_subject)
            client_cert.issuer = cacert.issuer
            client_cert.not_before = Time.now
            client_cert.not_after = Time.now + ((Integer(Config.get('global.authentication.methods.ssl.client.max_age')) rescue 365) * 24 * 60 * 60)
            client_cert.public_key = key.public_key
            client_cert.serial = 0x0
            client_cert.version = 2


          # add extensions (don't entirely know what these do)
            ef = OpenSSL::X509::ExtensionFactory.new
            ef.subject_certificate = client_cert
            ef.issuer_certificate = cacert

            client_cert.extensions = [
              ef.create_extension("basicConstraints","CA:TRUE", true),
              ef.create_extension("subjectKeyIdentifier", "hash")
            ]

          # sign it
            client_cert.sign(key, OpenSSL::Digest::SHA256.new)

          # save this key
            user.client_keys[params[:name]] = {
              :name       => params[:name],
              :public_key => client_cert.to_pem,
              :created_at => Time.now
            }

            user.save()

            content_type 'text/plain'

          # allow saving the certificate in various container formats
            case params[:cert]
            when 'pkcs12'
            # optionally return the cert inline (default is to download)
              headers 'Content-Disposition' => "attachment; filename=#{user.id}-#{params[:name]}.p12" unless params[:download].to_bool
              return OpenSSL::PKCS12.create(params[:name], params[:name], key, client_cert).to_der rescue nil
            else
            # optionally download the PEM (default is to display)
              headers 'Content-Disposition' => "attachment; filename=#{user.id}-#{params[:name]}.pem" if params[:download].to_bool
              return key.to_pem + "\n\n" + client_cert.to_pem
            end
          else
            halt 403, "Cannot download previously-generated key"
          end
        end

        delete '/:id/keys/:name' do
          id = (params[:id] == 'current' ? @user.id : params[:id])

          #allowed_to? :remove_api_key, id

          user = User.find_by_id(id)
          return 404 unless user
          return 404 unless user.client_keys.keys.include?(params[:name])

          user.client_keys.delete(params[:name])
          user.save()

          200
        end
      end

    # group management
      namespace '/groups' do
      # list groups
        get '/list' do
          allowed_to? :list_groups
          output(Group.all)
        end

      # get group
        get '/:group' do
          allowed_to? :get_group, params[:group]
          group = Group.find(params[:group])
          return 404 unless group
          output(group)
        end

      # update group
        post '/:group' do
          allowed_to? :update_group, params[:group]

          json = JSON.load(request.env['rack.input'].read)

          if json
          # remove certain fields
            json.delete_if{|k,v|
              k =~ /(?:^_?id$|^_?type$|_at$)/
            }

            group = Group.find_or_create(params[:group])
            group.from_json(json).save()
            group.reload

            output(group)
          else
            raise "Invalid JSON submitted"
          end
        end

      # add user to group
        get '/:group/add/:user' do
          allowed_to? :add_to_group, params[:group], params[:user]
          group = Group.find(params[:group])
          user = User.find_by_id(params[:user])
          return 404 unless group and user

          unless group.users.include?(user.id)
            group.users << user.id
            group.save()
          end

          output(group)
        end

      # remove user from group
        get '/:group/remove/:user' do
          allowed_to? :remove_from_group, params[:group], params[:user]
          group = Group.find(params[:group])
          user = User.find_by_id(params[:user])
          return 404 unless group and user

          group.users.delete(user.id) && group.save()
          output(group)
        end

      # grant group a given capability
        get '/:group/grant/:capability' do
          allowed_to? :grant_capability_to_group, params[:capability], params[:group]
          group = Group.find(params[:group])
          capability = Capability.find(params[:capability])
          return 404 unless group and capability

          capability.groups << group.id && capability.save()
          200
        end
      end

    # capability management
      namespace '/capabilities' do
      # list capabilities
        %w{
          /list
          /list/:parent
        }.each do |route|
          get route do
            allowed_to? :list_capabilities, params[:parent]
            output(Capability.where({
              :capabilities.exists => false
            }))
          end
        end

      # list capabilities for user

      # list capabilities for group

      # get capability
        get '/:id' do
          allowed_to? :get_capability, params[:id]
          capability = Capability.find(params[:id])
          return 404 unless capability
          output(capability)
        end

      # update capability
        post '/:id' do
          allowed_to? :update_capability, params[:id]
          json = JSON.load(request.env['rack.input'].read)

          if json
          # remove these fields
            json.delete('_id')
            json.delete('_type')

            capability = Capability.find_or_create(id)
            capability.from_json(json).save()

            200
          else
            raise "Invalid JSON submitted"
          end
        end

      # delete capability

      end
    end
  end
end
