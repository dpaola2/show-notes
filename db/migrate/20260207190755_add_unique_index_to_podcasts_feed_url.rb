class AddUniqueIndexToPodcastsFeedUrl < ActiveRecord::Migration[8.1]
  def change
    add_index :podcasts, :feed_url, unique: true
  end
end
