# machines may view their own objects
User.capability :get_asset do |cap, user, args|
  (( (user.class.ancestors.include?(DeviceUser) rescue false) && user.id == args.first) rescue false) || (Capability.user_can?(user.id, cap))
end

# machines may update their own objects
User.capability :update_asset do |cap, user, args|
  (( (user.class.ancestors.include?(DeviceUser) rescue false) && user.id == args.first) rescue false) || (Capability.user_can?(user.id, cap))
end

# users may remove their own notes within a certain period of time
User.capability :remove_asset_note do |cap, user, args|
  remove_own = (user.id == args.first['user_id'])
  time_limit = ((Time.now.to_i - args.first['created_at'].to_i) < 900)

  (remove_own) || Capability.user_can?(user.id, cap)
end


User.capability :bulk_update_assets
User.capability :query_assets
User.capability :remove_asset
