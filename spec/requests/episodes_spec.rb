require "rails_helper"

RSpec.describe "Episodes", type: :request do
  let!(:user) { create(:user) }

  before do
    sign_in_as(user)
  end

  describe "GET /episodes/:id" do
    let(:podcast) { create(:podcast, title: "Test Podcast") }
    let!(:subscription) { create(:subscription, user: user, podcast: podcast) }
    let(:episode) { create(:episode, podcast: podcast, title: "Test Episode", audio_url: "https://example.com/episode.mp3") }

    context "DIG-003: episode show page with summary" do
      let!(:summary) do
        create(:summary, episode: episode, sections: [
          { "title" => "Introduction", "content" => "The host welcomes listeners and introduces the topic of remote work." },
          { "title" => "Main Discussion", "content" => "A deep dive into async communication patterns." }
        ], quotes: [
          { "text" => "This changed everything for our team.", "start_time" => 845 }
        ])
      end

      it "renders the episode show page" do
        get episode_path(episode)

        expect(response).to have_http_status(:success)
      end

      it "displays the episode title" do
        get episode_path(episode)

        expect(response.body).to include("Test Episode")
      end

      it "displays the podcast name" do
        get episode_path(episode)

        expect(response.body).to include("Test Podcast")
      end

      it "displays summary sections" do
        get episode_path(episode)

        expect(response.body).to include("Introduction")
        expect(response.body).to include("remote work")
      end

      it "displays summary quotes" do
        get episode_path(episode)

        expect(response.body).to include("This changed everything for our team.")
      end
    end

    context "DIG-004: episode show page with audio player" do
      it "includes an audio player with the episode audio_url" do
        get episode_path(episode)

        expect(response.body).to include("https://example.com/episode.mp3")
      end
    end

    context "DIG-008: episode without summary shows processing state" do
      it "shows processing state when summary is not yet available" do
        get episode_path(episode)

        expect(response.body).to include("processing")
      end
    end

    context "Security: subscription scoping" do
      let(:other_user) { create(:user) }
      let(:unsubscribed_podcast) { create(:podcast) }
      let(:unsubscribed_episode) { create(:episode, podcast: unsubscribed_podcast) }

      it "redirects with alert when user is not subscribed to the podcast" do
        get episode_path(unsubscribed_episode)

        expect(response).to redirect_to(root_path)
      end

      it "does not show episodes from unsubscribed podcasts" do
        get episode_path(unsubscribed_episode)

        follow_redirect!
        expect(response.body).not_to include(unsubscribed_episode.title)
      end
    end

    context "authentication required" do
      it "redirects unauthenticated users to login" do
        # Reset authentication
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_call_original

        get episode_path(episode)

        expect(response).to redirect_to(login_path)
      end
    end
  end
end
