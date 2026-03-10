json.episodes @user_episodes do |user_episode|
  json.partial! "api/library/user_episode", user_episode: user_episode
end

json.meta do
  json.page @pagy.page
  json.pages @pagy.count.zero? ? 0 : @pagy.pages
  json.count @pagy.count
end
