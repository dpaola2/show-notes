require "rails_helper"

RSpec.describe "Inbox", type: :request do
  let!(:user) { create(:user) }

  before do
    sign_in_as(user)
  end

  describe "GET /inbox" do
    it "renders the inbox page" do
      get inbox_index_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Inbox")
    end

    context "with episodes in inbox" do
      let(:podcast) { create(:podcast, title: "Test Podcast") }
      let!(:episode) { create(:episode, podcast: podcast, title: "Test Episode") }
      let!(:user_episode) { create(:user_episode, user: user, episode: episode, location: :inbox) }

      it "displays the episode" do
        get inbox_index_path

        expect(response.body).to include("Test Episode")
        expect(response.body).to include("Test Podcast")
      end

      it "shows the Clear Inbox button" do
        get inbox_index_path

        expect(response.body).to include("Clear Inbox")
      end

      it "shows Add to Library button" do
        get inbox_index_path

        expect(response.body).to include("Add to Library")
      end

      it "shows Skip button" do
        get inbox_index_path

        expect(response.body).to include("Skip")
      end
    end

    context "with empty inbox" do
      it "shows empty state message" do
        get inbox_index_path

        expect(response.body).to include("Your inbox is empty")
      end

      it "does not show Clear Inbox button" do
        get inbox_index_path

        expect(response.body).not_to include("Clear Inbox")
      end
    end
  end

  describe "DELETE /inbox/clear" do
    context "with episodes in inbox" do
      let(:podcast) { create(:podcast) }

      before do
        3.times do |i|
          episode = create(:episode, podcast: podcast, title: "Episode #{i}")
          create(:user_episode, user: user, episode: episode, location: :inbox)
        end
      end

      it "moves all inbox episodes to trash" do
        expect {
          delete clear_inbox_index_path
        }.to change { user.user_episodes.in_inbox.count }.from(3).to(0)
      end

      it "sets trashed_at timestamp" do
        freeze_time do
          delete clear_inbox_index_path

          user.user_episodes.in_trash.each do |ue|
            expect(ue.trashed_at).to eq(Time.current)
          end
        end
      end

      it "redirects to inbox with success message" do
        delete clear_inbox_index_path

        expect(response).to redirect_to(inbox_index_path)
        follow_redirect!
        expect(response.body).to include("Cleared 3 episodes from inbox")
      end

      it "uses singular 'episode' for count of 1" do
        user.user_episodes.in_inbox.limit(2).destroy_all

        delete clear_inbox_index_path

        expect(response).to redirect_to(inbox_index_path)
        follow_redirect!
        expect(response.body).to include("Cleared 1 episode from inbox")
      end
    end

    context "with empty inbox" do
      it "redirects with alert message" do
        delete clear_inbox_index_path

        expect(response).to redirect_to(inbox_index_path)
        follow_redirect!
        expect(response.body).to include("Inbox is already empty")
      end

      it "does not create any trash records" do
        expect {
          delete clear_inbox_index_path
        }.not_to change { user.user_episodes.in_trash.count }
      end
    end

    context "with episodes in other locations" do
      let(:podcast) { create(:podcast) }

      before do
        # Episode in inbox
        inbox_episode = create(:episode, podcast: podcast)
        create(:user_episode, user: user, episode: inbox_episode, location: :inbox)

        # Episode in library (should not be affected)
        library_episode = create(:episode, podcast: podcast)
        create(:user_episode, user: user, episode: library_episode, location: :library)

        # Episode in archive (should not be affected)
        archive_episode = create(:episode, podcast: podcast)
        create(:user_episode, user: user, episode: archive_episode, location: :archive)
      end

      it "only clears inbox episodes" do
        delete clear_inbox_index_path

        expect(user.user_episodes.in_inbox.count).to eq(0)
        expect(user.user_episodes.in_library.count).to eq(1)
        expect(user.user_episodes.in_archive.count).to eq(1)
      end
    end
  end
end
