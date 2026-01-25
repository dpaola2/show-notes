require "rails_helper"

RSpec.describe CleanupTrashJob, type: :job do
  describe "#perform" do
    it "deletes episodes trashed more than 90 days ago" do
      old_trashed = create(:user_episode, :in_trash, trashed_at: 91.days.ago)
      another_old = create(:user_episode, :in_trash, trashed_at: 100.days.ago)

      expect {
        described_class.perform_now
      }.to change(UserEpisode, :count).by(-2)

      expect(UserEpisode.exists?(old_trashed.id)).to be false
      expect(UserEpisode.exists?(another_old.id)).to be false
    end

    it "keeps episodes trashed less than 90 days ago" do
      recent_trashed = create(:user_episode, :in_trash, trashed_at: 89.days.ago)
      very_recent = create(:user_episode, :in_trash, trashed_at: 1.day.ago)

      expect {
        described_class.perform_now
      }.not_to change(UserEpisode, :count)

      expect(UserEpisode.exists?(recent_trashed.id)).to be true
      expect(UserEpisode.exists?(very_recent.id)).to be true
    end

    it "keeps episodes trashed exactly 90 days ago" do
      freeze_time do
        exactly_90_days = create(:user_episode, :in_trash, trashed_at: 90.days.ago)

        expect {
          described_class.perform_now
        }.not_to change(UserEpisode, :count)

        expect(UserEpisode.exists?(exactly_90_days.id)).to be true
      end
    end

    it "does not delete episodes in other locations" do
      # These should not be deleted even if they were theoretically old
      inbox_episode = create(:user_episode, location: :inbox)
      library_episode = create(:user_episode, :in_library)
      archive_episode = create(:user_episode, :in_archive)

      expect {
        described_class.perform_now
      }.not_to change(UserEpisode, :count)
    end

    it "handles empty trash gracefully" do
      expect {
        described_class.perform_now
      }.not_to raise_error
    end
  end
end
