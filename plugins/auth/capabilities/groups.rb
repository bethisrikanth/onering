User.capability :list_groups
User.capability :add_to_group
User.capability :update_group
User.capability :grant_capability_to_group
User.capability :revoke_capability_from_group

# users can remove themselves from groups
User.capability :remove_from_group do |cap, user, group|
  (user.groups.include?(group)) || (Capability.user_can?(user.id, cap))
end

# users can see members of their own groups
User.capability :get_group do |cap, user, group|
  (user.groups.include?(group)) || (Capability.user_can?(user.id, cap))
end
