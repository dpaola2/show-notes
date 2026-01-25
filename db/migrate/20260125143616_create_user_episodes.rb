class CreateUserEpisodes < ActiveRecord::Migration[8.1]
  def change
    create_table :user_episodes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :episode, null: false, foreign_key: true
      t.integer :location, null: false, default: 0
      t.datetime :trashed_at
      t.integer :processing_status, null: false, default: 0
      t.text :processing_error

      t.timestamps
    end

    add_index :user_episodes, [ :user_id, :episode_id ], unique: true
  end
end
