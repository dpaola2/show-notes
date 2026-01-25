class CreatePodcasts < ActiveRecord::Migration[8.1]
  def change
    create_table :podcasts do |t|
      t.string :guid
      t.string :title
      t.string :author
      t.text :description
      t.string :feed_url
      t.string :artwork_url
      t.datetime :last_fetched_at

      t.timestamps
    end
    add_index :podcasts, :guid, unique: true
  end
end
