require 'openssl'

# user types
require 'core/models/ldap_user'
require 'core/models/pam_user'

require 'core/models/group'
require 'core/models/capability'

module App
  module Helpers
    def anonymous?(path)
      %w{
        /
        /api
        /api/core/users/login
      }.each do |p|
        return true if path == p
      end

      return false
    end
  end

  class Base < Controller
  # session based authentication
    before do
      unless Config.get('global.authentication.disable') then
        unless anonymous?(request.path)
          session_start!
          session! unless session?
          @user = User.find(session[:user]) if session[:user]
          throw :halt, 401 unless @user
        end
      end
    end

    namespace '/api/core' do
    # user management
      namespace '/users' do
      # get user list
        get '/list' do
          allowed_to? :list_users
          output(User.all.collect{|i| i.to_h })
        end

      # get user types list
        get '/list/types' do
          allowed_to? :list_users
          output(User.list(:_type))
        end

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

      # update user type
        get '/:id/type/:type' do
          allowed_to? :update_user_type, params[:id], params[:type]

          user = User.find(params[:id])
          return 404 unless user
          user._type = params[:type]
          user.safe_save
          output(user)
        end

      # generate a new client key for this user
        get '/:id/ssl/new' do
          #allowed_to? :generate_api_key, params[:id]
          user = User.find(params[:id])
          return 404 unless user

          keyfile = Config.get('global.authentication.ssl.ca.key')
          crtfile = Config.get('global.authentication.ssl.ca.cert')
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
          client_cert.subject = client_cert.issuer = OpenSSL::X509::Name.parse(client_subject)
          client_cert.not_before = Time.now
          client_cert.not_after = Time.now + ((Integer(Config.get('global.authentication.ssl.client.max_age')) rescue 365) * 24 * 60 * 60)
          client_cert.public_key = key.public_key
          client_cert.serial = 0x0
          client_cert.version = 2


        # this is happening now (for very present values of 'this')
          ef = OpenSSL::X509::ExtensionFactory.new
          ef.subject_certificate = client_cert
          ef.issuer_certificate = client_cert

          client_cert.extensions = [
            ef.create_extension("basicConstraints","CA:TRUE", true),
            ef.create_extension("subjectKeyIdentifier", "hash")
          ]

          client_cert.add_extension(ef.create_extension("authorityKeyIdentifier","keyid:always,issuer:always"))

          client_cert.sign(key, OpenSSL::Digest::SHA1.new)

          content_type 'text/plain'
          client_cert.to_pem
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