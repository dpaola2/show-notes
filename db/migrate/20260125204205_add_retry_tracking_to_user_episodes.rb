class AddRetryTrackingToUserEpisodes < ActiveRecord::Migration[8.1]
  def change
    add_column :user_episodes, :retry_count, :integer, default: 0, null: false
    add_column :user_episodes, :next_retry_at, :datetime
    add_column :user_episodes, :last_error_at, :datetime
  end
end
