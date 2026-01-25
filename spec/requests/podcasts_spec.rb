require "rails_helper"

RSpec.describe "Podcasts", type: :request do
  let!(:user) { create(:user) }

  describe "GET /podcasts" do
    it "renders the search page" do
      get podcasts_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Find Podcasts")
    end

    context "with a search query" do
      let(:search_results) do
        [
          {
            "id" => 123,
            "title" => "Test Podcast",
            "author" => "Test Author",
            "description" => "A great podcast",
            "artwork" => "https://example.com/art.jpg",
            "url" => "https://example.com/feed.xml"
          }
        ]
      end

      before do
        allow_any_instance_of(PodcastIndexClient).to receive(:search).and_return(search_results)
      end

      it "displays search results" do
        get podcasts_path(q: "test")

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Test Podcast")
        expect(response.body).to include("Test Author")
      end

      it "shows subscribe button for unsubscribed podcasts" do
        get podcasts_path(q: "test")

        expect(response.body).to include("Subscribe")
      end

      it "shows subscribed badge for subscribed podcasts" do
        podcast = create(:podcast, guid: "123")
        create(:subscription, user: user, podcast: podcast)

        get podcasts_path(q: "test")

        expect(response.body).to include("Subscribed")
      end
    end

    context "when search returns no results" do
      before do
        allow_any_instance_of(PodcastIndexClient).to receive(:search).and_return([])
      end

      it "displays no results message" do
        get podcasts_path(q: "nonexistent")

        expect(response.body).to include("No podcasts found")
      end
    end
  end

  describe "GET /podcasts/:id" do
    let(:podcast) { create(:podcast) }

    it "shows the podcast details" do
      get podcast_path(podcast)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(podcast.title)
    end

    it "shows episodes" do
      episode = create(:episode, podcast: podcast, title: "Episode 1")

      get podcast_path(podcast)

      expect(response.body).to include("Episode 1")
    end

    context "when user has episode in their library" do
      it "shows the current location" do
        episode = create(:episode, podcast: podcast)
        create(:user_episode, user: user, episode: episode, location: :library)

        get podcast_path(podcast)

        expect(response.body).to include("In Library")
      end
    end
  end

  describe "POST /podcasts" do
    let(:podcast_data) do
      {
        "id" => 456,
        "title" => "New Podcast",
        "author" => "New Author",
        "description" => "Description",
        "artwork" => "https://example.com/art.jpg",
        "url" => "https://example.com/feed.xml"
      }
    end

    before do
      allow_any_instance_of(PodcastIndexClient).to receive(:podcast).and_return(podcast_data)
      allow(FetchPodcastFeedJob).to receive(:perform_later)
    end

    it "creates a subscription" do
      expect {
        post podcasts_path(feed_id: 456)
      }.to change(Subscription, :count).by(1)
    end

    it "creates a podcast record" do
      expect {
        post podcasts_path(feed_id: 456)
      }.to change(Podcast, :count).by(1)
    end

    it "enqueues feed fetch job with initial_fetch flag" do
      post podcasts_path(feed_id: 456)

      podcast = Podcast.find_by(guid: "456")
      expect(FetchPodcastFeedJob).to have_received(:perform_later).with(podcast.id, initial_fetch: true)
    end

    it "redirects to subscriptions with success message" do
      post podcasts_path(feed_id: 456)

      expect(response).to redirect_to(subscriptions_path)
      follow_redirect!
      expect(response.body).to include("Subscribed to New Podcast")
    end

    context "when already subscribed" do
      before do
        podcast = create(:podcast, guid: "456")
        create(:subscription, user: user, podcast: podcast)
      end

      it "does not create a duplicate subscription" do
        expect {
          post podcasts_path(feed_id: 456)
        }.not_to change(Subscription, :count)
      end

      it "shows already subscribed message" do
        post podcasts_path(feed_id: 456)

        expect(response).to redirect_to(subscriptions_path)
        follow_redirect!
        expect(response.body).to include("Already subscribed")
      end
    end

    context "when podcast not found in API" do
      before do
        allow_any_instance_of(PodcastIndexClient).to receive(:podcast).and_return(nil)
      end

      it "redirects with error" do
        post podcasts_path(feed_id: 999)

        expect(response).to redirect_to(podcasts_path)
        follow_redirect!
        expect(response.body).to include("Podcast not found")
      end
    end
  end

  describe "DELETE /podcasts/:id" do
    let(:podcast) { create(:podcast) }

    before do
      create(:subscription, user: user, podcast: podcast)
    end

    it "removes the subscription" do
      expect {
        delete podcast_path(podcast)
      }.to change(Subscription, :count).by(-1)
    end

    it "redirects to subscriptions" do
      delete podcast_path(podcast)

      expect(response).to redirect_to(subscriptions_path)
      follow_redirect!
      expect(response.body).to include("Unsubscribed")
    end

    it "does not delete the podcast record" do
      expect {
        delete podcast_path(podcast)
      }.not_to change(Podcast, :count)
    end
  end
end
