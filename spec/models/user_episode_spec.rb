require "rails_helper"

RSpec.describe UserEpisode, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      user_episode = build(:user_episode)
      expect(user_episode).to be_valid
    end

    it "requires unique user_id + episode_id" do
      existing = create(:user_episode)
      duplicate = build(:user_episode, user: existing.user, episode: existing.episode)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("has already been taken")
    end
  end

  describe "enums" do
    it "defines location enum" do
      expect(described_class.locations.keys).to eq(%w[inbox library archive trash])
    end

    it "defines processing_status enum" do
      expect(described_class.processing_statuses.keys).to eq(
        %w[pending downloading transcribing summarizing ready error]
      )
    end
  end

  describe "scopes" do
    let!(:inbox_episode) { create(:user_episode, location: :inbox) }
    let!(:library_episode) { create(:user_episode, :in_library) }
    let!(:archive_episode) { create(:user_episode, :in_archive) }
    let!(:trash_episode) { create(:user_episode, :in_trash) }

    it ".in_inbox returns inbox episodes" do
      expect(described_class.in_inbox).to contain_exactly(inbox_episode)
    end

    it ".in_library returns library episodes" do
      expect(described_class.in_library).to contain_exactly(library_episode)
    end

    it ".in_archive returns archive episodes" do
      expect(described_class.in_archive).to contain_exactly(archive_episode)
    end

    it ".in_trash returns trash episodes" do
      expect(described_class.in_trash).to contain_exactly(trash_episode)
    end

    describe ".expired_trash" do
      it "returns episodes trashed more than 90 days ago" do
        old_trash = create(:user_episode, :in_trash, trashed_at: 91.days.ago)
        recent_trash = create(:user_episode, :in_trash, trashed_at: 1.day.ago)

        expect(described_class.expired_trash).to contain_exactly(old_trash)
      end
    end
  end

  describe "#move_to_library!" do
    it "updates location to library and resets processing" do
      user_episode = create(:user_episode, location: :inbox)
      user_episode.move_to_library!

      expect(user_episode.library?).to be true
      expect(user_episode.pending?).to be true
      expect(user_episode.trashed_at).to be_nil
    end
  end

  describe "#move_to_inbox!" do
    it "updates location to inbox" do
      user_episode = create(:user_episode, :in_trash)
      user_episode.move_to_inbox!

      expect(user_episode.inbox?).to be true
      expect(user_episode.trashed_at).to be_nil
    end
  end

  describe "#move_to_archive!" do
    it "updates location to archive" do
      user_episode = create(:user_episode, :ready)
      user_episode.move_to_archive!

      expect(user_episode.archive?).to be true
      expect(user_episode.trashed_at).to be_nil
    end
  end

  describe "#move_to_trash!" do
    it "updates location to trash and sets trashed_at" do
      user_episode = create(:user_episode, location: :inbox)
      freeze_time do
        user_episode.move_to_trash!

        expect(user_episode.trash?).to be true
        expect(user_episode.trashed_at).to eq(Time.current)
      end
    end
  end

  describe "delegation" do
    it "delegates title to episode" do
      episode = create(:episode, title: "Test Episode")
      user_episode = create(:user_episode, episode: episode)

      expect(user_episode.title).to eq("Test Episode")
    end

    it "delegates estimated_cost_cents to episode" do
      episode = create(:episode, duration_seconds: 3600)  # 1 hour
      user_episode = create(:user_episode, episode: episode)

      # AssemblyAI: 234 cents + Claude: 10 cents = 244 cents
      expect(user_episode.estimated_cost_cents).to eq(244)
    end
  end
end
