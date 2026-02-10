class AddProcessingStatusToEpisodes < ActiveRecord::Migration[8.1]
  def change
    add_column :episodes, :processing_status, :integer, default: 0, null: false
    add_column :episodes, :processing_error, :text
    add_column :episodes, :last_error_at, :datetime

    reversible do |dir|
      dir.up do
        # Backfill: episodes with both transcript and summary are ready (status 4)
        execute <<~SQL
          UPDATE episodes
          SET processing_status = 4
          WHERE id IN (
            SELECT e.id FROM episodes e
            INNER JOIN transcripts t ON t.episode_id = e.id
            INNER JOIN summaries s ON s.episode_id = e.id
          )
        SQL
      end
    end
  end
end
