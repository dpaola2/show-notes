class CreateEmailEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :email_events do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :event_type, null: false
      t.string :link_type
      t.references :episode, foreign_key: true
      t.datetime :triggered_at
      t.string :digest_date, null: false
      t.string :user_agent

      t.timestamps
    end

    add_index :email_events, :token, unique: true
    add_index :email_events, [ :user_id, :digest_date ]
    add_index :email_events, [ :episode_id, :event_type ]
  end
end
