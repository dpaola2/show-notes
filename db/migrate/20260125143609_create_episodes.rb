class CreateEpisodes < ActiveRecord::Migration[8.1]
  def change
    create_table :episodes do |t|
      t.string :guid
      t.references :podcast, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.string :audio_url
      t.integer :duration_seconds
      t.datetime :published_at

      t.timestamps
    end
    add_index :episodes, :guid, unique: true
  end
end
