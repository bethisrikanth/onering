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
      set :session_domain, Config.get('global.authentication.session.domain')
      set :session_path,   Config.get('global.authentication.session.path', '/api')
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
      if Config.get('global.authentication.autologin')
        @user = User.find(Config.get('global.authentication.autologin'))
      else
        unless anonymous?(request.path)
          @bootstrapUser = false

          if not (bstoken = (params[:bootstrap] || request.env['HTTP_X_AUTH_BOOTSTRAP_TOKEN'])).nil?
            if bstoken.to_s =~ /[0-9a-f]{32,64}/
              bsuser = User.urlquery("tokens.key/#{bstoken}").to_a
          
              if bsuser.length == 1
                if bsuser.first.id == Config.get('global.authentication.bootstrap.user') and not bsuser.first.id.nil?
                  @bootstrapUser = true
                else
                  halt 401, "No bootstrap user configured, cannot autogenerate user"
                end
              else
                halt 401, "Bootstrap user not found, cannot autogenerate user"
              end
            else
              halt 401, "Invalid bootstrap token specified, cannot autogenerate user"
            end
          end

          if not @user and not @bootstrapUser
            mechanism = (request.env['HTTP_X_AUTH_MECHANISM'] || (params[:token].nil? ? nil : 'token')).to_s.downcase

            case mechanism
            when 'basic'
              auth = Rack::Auth::Basic::Request.new(request.env)

              if auth.provided? and auth.basic? and auth.credentials
                user = User.find(auth.credentials.first)
                halt 401 if user.nil?

                user = user_authenticate(user, auth.credentials.last)
                halt 401 if user.nil?

                @user = user
              else
                response['WWW-Authenticate'] = "Basic realm=\"Onering on #{ENV['SERVER_NAME']}\""
                halt 401
              end

            when 'token'
            # token specified in the URL itself
              if params[:token] =~ /[0-9a-f]{32,64}/
                token = params[:token]
            # token specified in the X-Auth-Token HTTP request header
              elsif not request.env['HTTP_X_AUTH_TOKEN'].nil?
                token = request.env['HTTP_X_AUTH_TOKEN']
              else
                halt 401, "Invalid API token specified"
              end

              if not token.nil?
                user = User.urlquery("tokens.key/#{token}").to_a

                if user.length == 1
                  @user = user.first
                else
                  halt 401, "Invalid API token specified"
                end
              else
                halt 401, "Token authentication mechanism specified but no token given"
              end
            else
              session_start!
              session! unless session?
              @user = User.find(session[:user]) if session[:user]

            end
          end

          halt 401, "Invalid authentication request" unless @user or @bootstrapUser
        end
      end
    end

    namespace '/api' do
    # user management
      namespace '/users' do
      # get user list
        get '/list' do
          allowed_to? :list_users
          output(User.implementers.to_a.reject{|i|
            i == Kernel.const_get(Config.get('global.authentication.machine_user_type', 'DeviceUser'))
          }.collect{|i|
            i.all(@queryparams).collect{|j|
              j.to_hash()
            }
          }.flatten)
        end

        get '/list/machines' do
          allowed_to? :list_machines
          output(Kernel.const_get(Config.get('global.authentication.machine_user_type', 'DeviceUser')).all(@queryparams).collect{|i|
            {
              :id         => i.id,
              :created_at => i.created_at,
              :updated_at => i.updated_at
            }
          })
        end

      # get user types list
        get '/list/types' do
          allowed_to? :list_users
          output(User.implementers.to_a.collect{|i| i.name.gsub('User','').downcase }.compact.reject{|i| i.empty? })
        end

      # perform session login
        post '/login' do
          json = MultiJson.load(request.env['rack.input'].read)

          if json
            user = User.find(json['username'])
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
          user = User.find(id)
          return 404 unless user
          output(user.to_hash().merge({
            :groups       => user.groups(),
            :capabilities => user.capabilities()
          }))
        end

      # update user
        post '/:id' do
          id = (params[:id] == 'current' ? @user.id : params[:id])

          allowed_to? :update_user, id

          json = MultiJson.load(request.env['rack.input'].read)

          if json
          # remove certain fields
            json.delete_if{|k,v|
              k =~ /(?:^_?id$|_at$|^new$)/
            }

            type = (Kernel.const_get((json['type'].gsub(/_user$/,'') + '_user').camelize) rescue nil)
            raise "Cannot find user type #{json['type']}" if type.nil?

            user = User.find(id)
            user = type.new({
              :id => id
            }) if user.nil?

            user.from_hash(json.symbolize_keys)
            user.save()
            output(user)
          else
            raise "Invalid JSON submitted"
          end
        end

      # delete user
        delete '/:id' do
          allowed_to? :delete_user
          user = User.find(params[:id])
          return 404 unless user

          raise "Delete failed for user #{params[:id]}" unless user.destroy()
          200
        end

      # set user gravatar image
        get '/:id/gravatar' do
          id = (params[:id] == 'current' ? @user.id : params[:id])
          allowed_to? :get_user, id

          user = User.find(id)
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
          user = User.find(id)
          return 404 unless user

          halt 200 if user.client_keys.keys.include?(params[:name])
          halt 404
        end

      # generate a new API token
        get '/:id/tokens/:name' do
          id = (params[:id] == 'current' ? (@user ? @user.id : params[:id]) : params[:id])
          user = User.find(id)

        # this is also where pre-validated devices go to retrieve their API key
          if user.nil? and @bootstrapUser === true and not id === 'current'
            machine_klass = Config.get('global.authentication.machine_user_type', 'DeviceUser').constantize()

            machine_klass.create({
              :id => id
            })
          end

          user = User.find(id)
          return 404 unless user

          content_type 'text/plain'
          user.token(params[:name])
        end


        delete '/:id/tokens/:name' do
          id = (params[:id] == 'current' ? (@user ? @user.id : params[:id]) : params[:id])
          user = User.find(id)
          return 404 unless user

          user.tokens.delete_if{|i| i['name'] == params[:name] }
          user.save()

          200
        end

      # generate a new client key for this user
        get '/:id/keys/:name' do
          halt 404
          id = (params[:id] == 'current' ? (@user ? @user.id : params[:id]) : params[:id])

        # this is also where pre-validated devices go to retrieve their API key
          if @bootstrapUser === true and not id === 'current'
            machine_klass = Config.get('global.authentication.machine_user_type', 'DeviceUser').constantize()

            machine_klass.create({
              :id => id
            })
          end


          #allowed_to? :generate_api_key, id

          user = User.find(id)
          return 404 unless user

          if user.client_keys[params[:name]].nil?
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
          # TODO: Oh man this is some sad stuff right here...
          #       Need to refactor Tensor such that fields are actually classes
          #       instead of some weird type tracking thing
          #
            user.client_keys = user.client_keys.stringify_keys.merge({
              params[:name] => {
                :name       => params[:name],
                :public_key => client_cert.to_pem,
                :created_at => Time.now
              }
            })

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

          user = User.find(id)
          return 404 unless user
          return 404 unless user.client_keys.keys.include?(params[:name])

          user.client_keys = user.client_keys.reject{|k,v|
            k.to_s == params[:name].to_s
          }

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

          json = MultiJson.load(request.env['rack.input'].read)

          if json
          # remove certain fields
            json.delete_if{|k,v|
              k =~ /(?:^_?id$|^_?type$|_at$)/
            }

            group = (Group.find(params[:group]) || Group.create({
              :id => params[:group]
            }))

            group.from_hash(json).save()
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
          user = User.find(params[:user])
          return 404 unless group and user

          unless group.users.include?(user.id)
            group.users = (group.users + [user.id]).uniq
            group.save()
          end

          output(group)
        end

      # remove user from group
        get '/:group/remove/:user' do
          allowed_to? :remove_from_group, params[:group], params[:user]
          group = Group.find(params[:group])
          user = User.find(params[:user])
          return 404 unless group and user

          group.users = (group.users - [user.id])
          group.save()

          output(group)
        end

      # grant group a given capability
        get '/:group/grant/:capability' do
          allowed_to? :grant_capability_to_group, params[:capability], params[:group]
          group = Group.find(params[:group])
          capability = Capability.find(params[:capability])
          return 404 unless group and capability

          capability.groups = (capability.groups + [group.id]).uniq
          capability.save()
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
            output(Capability.search({
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
          json = MultiJson.load(request.env['rack.input'].read)

          if json
          # remove these fields
            json.delete('_id')
            json.delete('_type')

            capability = (Capability.find(id) || Capability.create({
              :id => id
            }))

            capability.from_hash(json).save()
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
