class BackfillDigestFeaturedAtForExistingLibrary < ActiveRecord::Migration[8.1]
  # Idempotent by virtue of WHERE digest_featured_at IS NULL — re-running this
  # migration in any environment is safe.
  def up
    UserEpisode
      .where(
        location: UserEpisode.locations[:library],
        processing_status: UserEpisode.processing_statuses[:ready],
        digest_featured_at: nil
      )
      .update_all(digest_featured_at: Time.current)
  end

  def down
    UserEpisode.update_all(digest_featured_at: nil, digest_last_appeared_at: nil)
  end
end
