class AddDigestTrackingToUserEpisodes < ActiveRecord::Migration[8.1]
  def change
    add_column :user_episodes, :digest_featured_at, :datetime
    add_column :user_episodes, :digest_last_appeared_at, :datetime

    add_index :user_episodes, [ :user_id, :digest_featured_at ],
              name: "index_user_episodes_on_user_id_and_digest_featured_at"
  end
end
