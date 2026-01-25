class CreateSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :summaries do |t|
      t.references :episode, null: false, foreign_key: true
      t.jsonb :sections
      t.jsonb :quotes
      t.text :searchable_text

      t.timestamps
    end
  end
end
