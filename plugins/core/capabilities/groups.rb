User.capability :list_groups
User.capability :add_to_group

# users can remove themselves from groups
User.capability :remove_from_group do |cap, user|
  (user.groups.include?(args.first)) || (Capability.user_can?(user.id, cap))
end

# users can see members of their own groups
User.capability :get_group do |cap, user|
  (user.groups.include?(args.first)) || (Capability.user_can?(user.id, cap))
end
