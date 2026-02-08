class ReplaceEpisodesGuidIndexWithPodcastScoped < ActiveRecord::Migration[8.1]
  def change
    remove_index :episodes, :guid, unique: true
    add_index :episodes, [ :podcast_id, :guid ], unique: true
  end
end
