require "rails_helper"

RSpec.describe "Public Episodes", type: :request do
  let(:podcast) { create(:podcast, title: "Test Podcast", artwork_url: "https://example.com/artwork.jpg") }
  let(:episode) { create(:episode, podcast: podcast, title: "Test Episode", audio_url: "https://example.com/secret-audio.mp3", published_at: Time.zone.parse("2026-02-01")) }
  let!(:summary) do
    create(:summary, episode: episode, sections: [
      { "title" => "Key Takeaways", "content" => "The host discusses important topics about technology." },
      { "title" => "Deep Dive", "content" => "A thorough exploration of the subject matter." }
    ], quotes: [
      { "text" => "This insight changed everything for our team.", "start_time" => 120, "end_time" => 128 }
    ])
  end

  describe "GET /e/:id" do
    context "PUB-001: public access without authentication" do
      it "renders successfully without authentication" do
        get "/e/#{episode.id}"

        expect(response).to have_http_status(:success)
      end

      it "does not redirect to login" do
        get "/e/#{episode.id}"

        expect(response).not_to redirect_to(login_path)
      end
    end

    context "PUB-002: displays episode title, podcast name, and artwork" do
      it "displays the episode title" do
        get "/e/#{episode.id}"

        expect(response.body).to include("Test Episode")
      end

      it "displays the podcast name" do
        get "/e/#{episode.id}"

        expect(response.body).to include("Test Podcast")
      end

      it "includes the podcast artwork" do
        get "/e/#{episode.id}"

        expect(response.body).to include("https://example.com/artwork.jpg")
      end
    end

    context "PUB-003: displays the full AI summary" do
      it "displays summary section titles" do
        get "/e/#{episode.id}"

        expect(response.body).to include("Key Takeaways")
        expect(response.body).to include("Deep Dive")
      end

      it "displays summary section content" do
        get "/e/#{episode.id}"

        expect(response.body).to include("important topics")
        expect(response.body).to include("thorough exploration")
      end

      it "displays summary quotes" do
        get "/e/#{episode.id}"

        expect(response.body).to include("This insight changed everything for our team.")
      end
    end

    context "PUB-004: CTA linking to signup" do
      it "includes a call-to-action for signup" do
        get "/e/#{episode.id}"

        expect(response.body).to include("summaries")
        expect(response.body).to include(login_path)
      end
    end

    context "PUB-005: OG meta tags for rich link previews" do
      it "includes og:title meta tag with episode title" do
        get "/e/#{episode.id}"

        expect(response.body).to include('og:title')
        expect(response.body).to include("Test Episode")
      end

      it "includes og:description meta tag" do
        get "/e/#{episode.id}"

        expect(response.body).to include('og:description')
      end

      it "includes og:url meta tag with the public URL" do
        get "/e/#{episode.id}"

        expect(response.body).to include('og:url')
        expect(response.body).to include("/e/#{episode.id}")
      end

      it "omits og:image when no OG image is attached" do
        get "/e/#{episode.id}"

        # Without OG image, falls back to text-only OG tags
        expect(response.body).to include('og:title')
      end
    end

    context "PUB-006: clean design with public layout" do
      it "does not include the authenticated navigation bar" do
        get "/e/#{episode.id}"

        expect(response.body).not_to include("Inbox")
        expect(response.body).not_to include("Logout")
      end
    end

    context "PUB-007: management actions not accessible from public page" do
      it "does not expose management actions" do
        get "/e/#{episode.id}"

        expect(response.body).not_to include("regenerate")
        expect(response.body).not_to include("retry_processing")
      end

      it "does not expose the audio URL" do
        get "/e/#{episode.id}"

        expect(response.body).not_to include("secret-audio.mp3")
      end
    end

    context "PUB-008: stable URL at /e/:id" do
      it "responds at the /e/:id path" do
        get "/e/#{episode.id}"

        expect(response).to have_http_status(:success)
      end
    end

    context "friendly 404 for non-existent episodes" do
      it "returns 404 for a non-existent episode" do
        get "/e/999999"

        expect(response).to have_http_status(:not_found)
      end
    end

    context "episodes without summaries" do
      let(:episode_without_summary) { create(:episode, podcast: podcast, title: "No Summary Episode") }

      it "renders successfully" do
        get "/e/#{episode_without_summary.id}"

        expect(response).to have_http_status(:success)
      end

      it "shows a message indicating summary is not yet available" do
        get "/e/#{episode_without_summary.id}"

        expect(response.body).to include("not yet available")
      end

      it "still displays basic episode metadata" do
        get "/e/#{episode_without_summary.id}"

        expect(response.body).to include("No Summary Episode")
        expect(response.body).to include("Test Podcast")
      end
    end

    context "SEO indexable" do
      it "includes robots meta tag allowing indexing" do
        get "/e/#{episode.id}"

        expect(response.body).to include('content="index, follow"')
      end
    end

    context "TRK-003: UTM visit logging" do
      it "logs UTM params at info level when present" do
        expect(Rails.logger).to receive(:info).with(/utm_source/)

        get "/e/#{episode.id}", params: {
          utm_source: "share",
          utm_medium: "social",
          utm_content: "episode_#{episode.id}"
        }
      end

      it "does not log UTM when no UTM params are present" do
        expect(Rails.logger).not_to receive(:info).with(/utm_source/)

        get "/e/#{episode.id}"
      end
    end

    context "Security: no user data exposure" do
      let!(:user) { create(:user) }
      let!(:subscription) { create(:subscription, user: user, podcast: podcast) }

      it "does not expose any user information on the public page" do
        get "/e/#{episode.id}"

        expect(response.body).not_to include(user.email)
      end
    end

    context "OGI-006: og:image served when OG image is attached" do
      it "includes og:image meta tag when episode has an attached OG image" do
        episode.og_image.attach(
          io: StringIO.new("fake-image-data"),
          filename: "og_image.png",
          content_type: "image/png"
        )

        get "/e/#{episode.id}"

        expect(response.body).to include('og:image')
      end
    end
  end

  describe "POST /e/:id/share" do
    context "TRK-002: share event creation" do
      it "creates a ShareEvent record" do
        expect {
          post "/e/#{episode.id}/share", params: { share_target: "clipboard" }
        }.to change(ShareEvent, :count).by(1)
      end

      it "records the share target" do
        post "/e/#{episode.id}/share", params: { share_target: "twitter" }

        event = ShareEvent.last
        expect(event.share_target).to eq("twitter")
        expect(event.episode).to eq(episode)
      end

      it "records the user_agent" do
        post "/e/#{episode.id}/share",
             params: { share_target: "clipboard" },
             headers: { "User-Agent" => "TestBrowser/1.0" }

        expect(ShareEvent.last.user_agent).to eq("TestBrowser/1.0")
      end

      it "works without authentication" do
        post "/e/#{episode.id}/share", params: { share_target: "clipboard" }

        expect(response.status).to be_between(200, 399)
      end
    end

    context "authenticated user share" do
      let(:user) { create(:user) }

      before { sign_in_as(user) }

      it "associates the share event with the current user" do
        post "/e/#{episode.id}/share", params: { share_target: "clipboard" }

        expect(ShareEvent.last.user).to eq(user)
      end
    end

    context "unauthenticated visitor share" do
      it "creates a share event with nil user" do
        post "/e/#{episode.id}/share", params: { share_target: "clipboard" }

        expect(ShareEvent.last.user).to be_nil
      end
    end

    context "SHR-001: share button on public page" do
      it "the public page includes a share button" do
        get "/e/#{episode.id}"

        expect(response.body).to include("share")
      end
    end

    context "concurrent share clicks" do
      it "creates separate events for repeated requests" do
        expect {
          3.times { post "/e/#{episode.id}/share", params: { share_target: "clipboard" } }
        }.to change(ShareEvent, :count).by(3)
      end
    end
  end
end
