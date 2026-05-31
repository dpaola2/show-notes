require "rails_helper"

# Verifies that controllers emit the expected PostHog events via the Analytics
# wrapper, tagged with the correct `platform` property. Analytics.capture is
# stubbed so no real network calls happen (and so these pass without a key).
RSpec.describe "Analytics instrumentation", type: :request do
  let(:user) { create(:user) }
  let(:podcast) { create(:podcast) }

  describe "iOS (API) events are tagged platform: ios" do
    let(:token) { api_sign_in_as(user) }

    it "captures episode_skipped when an inbox episode is skipped" do
      episode = create(:episode, podcast: podcast)
      ue = create(:user_episode, user: user, episode: episode, location: :inbox)

      expect(Analytics).to receive(:capture).with(
        hash_including(event: "episode_skipped", properties: hash_including(platform: "ios", source: "inbox"))
      )

      post "/api/inbox/#{ue.id}/skip", headers: api_headers(token), as: :json
      expect(response).to have_http_status(:ok)
    end

    it "captures episode_retry_requested when a library episode is retried" do
      episode = create(:episode, podcast: podcast)
      ue = create(:user_episode, :with_error, user: user, episode: episode)

      expect(Analytics).to receive(:capture).with(
        hash_including(event: "episode_retry_requested", properties: hash_including(platform: "ios", source: "library"))
      )

      post "/api/library/#{ue.id}/retry_processing", headers: api_headers(token), as: :json
      expect(response).to have_http_status(:ok)
    end

    it "uses the user id as the distinct_id" do
      episode = create(:episode, podcast: podcast)
      ue = create(:user_episode, user: user, episode: episode, location: :inbox)

      expect(Analytics).to receive(:capture).with(hash_including(distinct_id: user.id.to_s))

      post "/api/inbox/#{ue.id}/skip", headers: api_headers(token), as: :json
    end
  end

  describe "web events are tagged platform: web" do
    it "captures user_signed_up for a brand-new email" do
      expect(Analytics).to receive(:capture).with(
        hash_including(event: "user_signed_up", properties: hash_including(platform: "web"))
      )

      post login_path, params: { email: "brand-new-user@example.com" }
      expect(response).to redirect_to(magic_link_sent_path)
    end

    it "captures episode_shared from the public share endpoint" do
      episode = create(:episode, podcast: podcast)

      expect(Analytics).to receive(:capture).with(
        hash_including(event: "episode_shared", properties: hash_including(platform: "web", share_target: "native"))
      )

      post share_episode_path(id: episode.id), params: { share_target: "native" }
      expect(response).to have_http_status(:created)
    end
  end
end
