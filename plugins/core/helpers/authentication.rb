module App
  class Base < Controller
    namespace '/api/core' do
    # user management
      namespace '/users' do
      # get user list
        get '/list' do
          allowed_to? :list_users
          output(User.all.collect{|i| i.to_h })
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
          # remove these fields
            json.delete('_id')
            json.delete('_type')

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
          user.type = params[:type]
          user.safe_save
          output(user)
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