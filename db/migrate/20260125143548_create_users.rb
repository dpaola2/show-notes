class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :magic_token
      t.datetime :magic_token_expires_at

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
