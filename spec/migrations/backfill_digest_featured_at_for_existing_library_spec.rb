require "rails_helper"

# Migration spec for the BackfillDigestFeaturedAtForExistingLibrary data migration.
# Loads the migration class explicitly and exercises its `up` and `down` methods
# against the test database. The DDL migration (AddDigestTrackingToUserEpisodes)
# must already be applied before this spec runs (db:test:prepare handles that).
#
# Covers SN-17 / M1 acceptance criteria:
#   - VAL-002: every library+ready UserEpisode is stamped with digest_featured_at
#   - Exclusions: inbox, archive, trash, and non-ready library rows are not stamped
#   - Idempotency: a second `up` invocation produces zero additional updates
#   - `down` clears digest_featured_at + digest_last_appeared_at for all rows
RSpec.describe "BackfillDigestFeaturedAtForExistingLibrary migration", type: :model do
  let(:migration_path) do
    Rails.root.glob("db/migrate/*_backfill_digest_featured_at_for_existing_library.rb").first
  end

  let(:migration_class) do
    require migration_path.to_s
    BackfillDigestFeaturedAtForExistingLibrary
  end

  let(:migration) { migration_class.new }

  let(:user) { create(:user) }
  let(:podcast) { create(:podcast) }

  describe "#up" do
    context "VAL-002: stamps digest_featured_at on library + ready UserEpisodes" do
      it "sets digest_featured_at on a library + ready UserEpisode" do
        ue = create(:user_episode, :ready, user: user, episode: create(:episode, podcast: podcast))
        ue.update_columns(digest_featured_at: nil, digest_last_appeared_at: nil)

        expect { migration.up }
          .to change { ue.reload.digest_featured_at }.from(nil)

        expect(ue.digest_featured_at).to be_within(2.seconds).of(Time.current)
      end

      it "stamps every eligible UserEpisode in a single run" do
        eligible = 3.times.map do
          ue = create(:user_episode, :ready, user: user, episode: create(:episode, podcast: podcast))
          ue.update_columns(digest_featured_at: nil)
          ue
        end

        migration.up

        eligible.each do |ue|
          expect(ue.reload.digest_featured_at).not_to be_nil
        end
      end
    end

    context "exclusions: does not touch ineligible UserEpisodes" do
      it "does not stamp UserEpisodes in inbox" do
        ue = create(:user_episode, user: user, episode: create(:episode, podcast: podcast),
                                   location: :inbox, processing_status: :ready)
        ue.update_columns(digest_featured_at: nil)

        migration.up

        expect(ue.reload.digest_featured_at).to be_nil
      end

      it "does not stamp UserEpisodes in archive" do
        ue = create(:user_episode, user: user, episode: create(:episode, podcast: podcast),
                                   location: :archive, processing_status: :ready)
        ue.update_columns(digest_featured_at: nil)

        migration.up

        expect(ue.reload.digest_featured_at).to be_nil
      end

      it "does not stamp UserEpisodes in trash" do
        ue = create(:user_episode, user: user, episode: create(:episode, podcast: podcast),
                                   location: :trash, processing_status: :ready, trashed_at: 1.day.ago)
        ue.update_columns(digest_featured_at: nil)

        migration.up

        expect(ue.reload.digest_featured_at).to be_nil
      end

      it "does not stamp library UserEpisodes whose processing_status is not ready" do
        ue = create(:user_episode, :in_library, user: user, episode: create(:episode, podcast: podcast),
                                                processing_status: :pending)
        ue.update_columns(digest_featured_at: nil)

        migration.up

        expect(ue.reload.digest_featured_at).to be_nil
      end

      it "does not stamp library + transcribing UserEpisodes" do
        ue = create(:user_episode, :processing, user: user, episode: create(:episode, podcast: podcast))
        ue.update_columns(digest_featured_at: nil)

        migration.up

        expect(ue.reload.digest_featured_at).to be_nil
      end
    end

    context "preserves rows already stamped" do
      it "does not overwrite digest_featured_at when it is already set" do
        original_time = 5.days.ago.change(usec: 0)
        ue = create(:user_episode, :ready, user: user, episode: create(:episode, podcast: podcast))
        ue.update_columns(digest_featured_at: original_time)

        migration.up

        expect(ue.reload.digest_featured_at).to be_within(1.second).of(original_time)
      end
    end

    context "idempotency: re-running produces zero additional updates" do
      it "is a no-op on the second invocation" do
        eligible = 2.times.map do
          ue = create(:user_episode, :ready, user: user, episode: create(:episode, podcast: podcast))
          ue.update_columns(digest_featured_at: nil)
          ue
        end

        migration.up
        first_stamps = eligible.map { |ue| ue.reload.digest_featured_at }

        # Second run — nothing should change because WHERE digest_featured_at IS NULL
        # excludes everything we just stamped.
        migration.up
        second_stamps = eligible.map { |ue| ue.reload.digest_featured_at }

        expect(second_stamps).to eq(first_stamps)
      end
    end
  end

  describe "#down" do
    it "clears digest_featured_at on all UserEpisodes" do
      ue = create(:user_episode, :ready, user: user, episode: create(:episode, podcast: podcast))
      ue.update_columns(digest_featured_at: 1.day.ago, digest_last_appeared_at: 1.day.ago)

      migration.down

      expect(ue.reload.digest_featured_at).to be_nil
      expect(ue.reload.digest_last_appeared_at).to be_nil
    end

    it "clears digest_last_appeared_at on all UserEpisodes" do
      ue1 = create(:user_episode, :ready, user: user, episode: create(:episode, podcast: podcast))
      ue1.update_columns(digest_featured_at: 1.day.ago, digest_last_appeared_at: 12.hours.ago)
      ue2 = create(:user_episode, user: user, episode: create(:episode, podcast: podcast),
                                  location: :inbox, processing_status: :ready,
                                  digest_last_appeared_at: 6.hours.ago)

      migration.down

      expect(ue1.reload.digest_last_appeared_at).to be_nil
      expect(ue2.reload.digest_last_appeared_at).to be_nil
    end
  end

  describe "schema (TRK-001 / TRK-002)" do
    it "has the digest_featured_at column on user_episodes" do
      expect(UserEpisode.column_names).to include("digest_featured_at")
    end

    it "has the digest_last_appeared_at column on user_episodes" do
      expect(UserEpisode.column_names).to include("digest_last_appeared_at")
    end

    it "has the composite (user_id, digest_featured_at) index on user_episodes" do
      indexes = ActiveRecord::Base.connection.indexes("user_episodes")
      composite = indexes.find { |i| i.columns == [ "user_id", "digest_featured_at" ] }
      expect(composite).not_to be_nil,
        "expected composite index on user_episodes(user_id, digest_featured_at), found: #{indexes.map(&:columns).inspect}"
    end
  end
end
