# you may update your own user, otherwise need to be granted :update_user
User.capability :update_user do |cap, user, args|
  (user.id == args.first) || (Capability.user_can?(user.id, cap))
end

# you may get your own user, otherwise need to be granted :get_user
User.capability :get_user do |cap, user, args|
  (user.id == args.first) || (Capability.user_can?(user.id, cap))
end


# default simply checks if the user is granted a capability
User.capability :list_users