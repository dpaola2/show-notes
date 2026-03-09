require "rails_helper"

RSpec.describe UserEpisode, "#restore_from_archive!", type: :model do
  describe "#restore_from_archive!" do
    it "sets location to library" do
      user_episode = create(:user_episode, :in_archive, processing_status: :ready)

      user_episode.restore_from_archive!

      expect(user_episode.library?).to be true
    end

    it "preserves processing_status of ready" do
      user_episode = create(:user_episode, :in_archive, processing_status: :ready)

      user_episode.restore_from_archive!

      expect(user_episode.processing_status).to eq("ready")
    end

    it "preserves processing_status of pending" do
      user_episode = create(:user_episode, :in_archive, processing_status: :pending)

      user_episode.restore_from_archive!

      expect(user_episode.processing_status).to eq("pending")
    end

    it "preserves processing_status of error" do
      user_episode = create(:user_episode, :in_archive, processing_status: :error)

      user_episode.restore_from_archive!

      expect(user_episode.processing_status).to eq("error")
    end

    it "is idempotent — restoring a library episode keeps it in library" do
      user_episode = create(:user_episode, :ready)

      user_episode.restore_from_archive!

      expect(user_episode.library?).to be true
      expect(user_episode.processing_status).to eq("ready")
    end
  end
end
