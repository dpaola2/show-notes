class CreateShareEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :share_events do |t|
      t.references :episode, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :share_target, null: false
      t.string :user_agent
      t.string :referrer

      t.timestamps
    end

    add_index :share_events, [ :episode_id, :share_target ]
  end
end
