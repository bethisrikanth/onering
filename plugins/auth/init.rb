require 'openssl'
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
                @user = User.find(cn) rescue nil
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

      # if two-factor is enabled or SSL client key was not present
        if (@user && @user.options['two_factor']) or (not @user and not @bootstrapUser)
          session_start!
          session! unless session?
          @user = User.find(session[:user]) if session[:user]
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
          }).collect{|i| i.to_h })
        end

        get '/list/machines' do
          allowed_to? :list_machines
          output(User.all({
            :_type => Config.get('global.authentication.machine_user_type', 'DeviceUser')
          }).collect{|i| i.to_h })
        end

      # get user types list
        get '/list/types' do
          allowed_to? :list_users
          output(User.list(:_type))
        end

      # perform session login
        post '/login' do
          json = JSON.load(request.env['rack.input'].read)

          if json
            user = User.find(json['username'])
            halt 401, 'Invalid username' unless user

          # and user/pass were good...
            if user.authenticate!({
              :password => json['password']
            })
              user.logged_in_at = Time.now
              user.safe_save
              @user = session[:user] = user.id

            else
              halt 401, 'Incorrect password'
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

          user = User.find(id)
          return 404 unless user
          output(user.to_h)
        end

      # update user
        post '/:id' do
          id = (params[:id] == 'current' ? @user.id : params[:id])

          allowed_to? :update_user, id

          json = JSON.load(request.env['rack.input'].read)

          if json
          # remove certain fields
            json.delete_if{|k,v|
              k =~ /(?:^_?id$|^_?type$|_at$)/
            }

            user = User.find_or_create(id)
            user.from_json(json).safe_save
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

      # update user type
        get '/:id/type/:type' do
          id = (params[:id] == 'current' ? @user.id : params[:id])

          allowed_to? :update_user_type, id, params[:type]

          user = User.find(id)
          return 404 unless user
          user._type = params[:type]
          user.safe_save
          output(user)
        end

      # generate a new client key for this user
        get '/:id/keys/:name' do
          id = (params[:id] == 'current' ? (@user ? @user.id : params[:id]) : params[:id])

          STDERR.puts @bootstrapUser.inspect

        # this is also where pre-validated devices go to retrieve their API key
          if @bootstrapUser === true and not id === 'current'
            DeviceUser.find_or_create(id, {})
          end


          #allowed_to? :generate_api_key, id

          user = User.find(id)
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
            client_cert.not_after = Time.now + ((Integer(Config.get!('global.authentication.methods.ssl.client.max_age')) rescue 365) * 24 * 60 * 60)
            client_cert.public_key = key.public_key
            client_cert.serial = 0x0
            client_cert.version = 2


          # add extensions (don't entirely know what these do)
            ef = OpenSSL::X509::ExtensionFactory.new
            ef.subject_certificate = client_cert
            ef.issuer_certificate = cacert

            client_cert.extensions = [
              ef.create_extension("basicConstraints","CA:TRUE", true),
              ef.create_extension("subjectKeyIdentifier", "hash"),
              ef.create_extension("authorityKeyIdentifier","keyid:always,issuer:always")
            ]

          # sign it
            client_cert.sign(key, OpenSSL::Digest::SHA256.new)

          # save this key
            user.client_keys[params[:name]] = {
              :name => params[:name],
              :public_key => client_cert.to_pem
            }

            user.safe_save

            content_type 'text/plain'

          # allow saving the certificate in various container formats
            case params[:cert]
            when 'pem'
            # optionally return the cert inline (default is to download)
              headers 'Content-Disposition' => "attachment; filename=#{params[:name]}.pem" unless params[:inline]
              return key.to_pem + "\n\n" + client_cert.to_pem
            else
            # optionally return the cert inline (default is to download)
              headers 'Content-Disposition' => "attachment; filename=#{params[:name]}.p12" unless params[:inline]
              return OpenSSL::PKCS12.create(params[:name], params[:name], key, client_cert).to_der rescue nil
            end
          else
            halt 403, "Cannot download previously-generated key"
          end
        end

        get '/:id/keys/:name/remove' do
          id = (params[:id] == 'current' ? @user.id : params[:id])

          #allowed_to? :remove_api_key, id

          user = User.find(id)
          return 404 unless user

          user.client_keys.delete(params[:name])
          user.safe_save

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

      # add user to group
        get '/:group/add/:user' do
          allowed_to? :add_to_group, params[:group], params[:user]
          group = Group.find(params[:group])
          user = User.find(params[:user])
          return 404 unless group and user

          unless group.users.include?(user.id)
            group.users << user.id
            group.safe_save
          end

          output(group)
        end

      # remove user from group
        get '/:group/remove/:user' do
          allowed_to? :remove_from_group, params[:group], params[:user]
          group = Group.find(params[:group])
          user = User.find(params[:user])
          return 404 unless group and user

          group.users.delete(user.id) && group.safe_save
          output(group)
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
            capability.from_json(json).safe_save

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
