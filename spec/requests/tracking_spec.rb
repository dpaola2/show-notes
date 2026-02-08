require "rails_helper"

RSpec.describe "Tracking", type: :request do
  describe "GET /t/:token (click tracking)" do
    context "TRK-002: click tracking on summary links" do
      let(:user) { create(:user) }
      let(:episode) { create(:episode) }
      let!(:event) { create(:email_event, :click_summary, user: user, episode: episode) }

      it "redirects to the episode show page" do
        get "/t/#{event.token}"

        expect(response).to redirect_to(episode_path(episode))
      end

      it "records triggered_at on the event" do
        freeze_time do
          get "/t/#{event.token}"

          expect(event.reload.triggered_at).to eq(Time.current)
        end
      end

      it "records user_agent on the event" do
        get "/t/#{event.token}", headers: { "User-Agent" => "TestBrowser/1.0" }

        expect(event.reload.user_agent).to eq("TestBrowser/1.0")
      end
    end

    context "TRK-003: click tracking on listen links" do
      let(:user) { create(:user) }
      let(:episode) { create(:episode) }
      let!(:event) { create(:email_event, :click_listen, user: user, episode: episode) }

      it "redirects to the episode page with audio anchor" do
        get "/t/#{event.token}"

        expect(response).to redirect_to(episode_path(episode, anchor: "audio"))
      end

      it "records triggered_at on the event" do
        freeze_time do
          get "/t/#{event.token}"

          expect(event.reload.triggered_at).to eq(Time.current)
        end
      end
    end

    context "TRK-006: graceful degradation for invalid token" do
      it "redirects to root_path when token is not found" do
        get "/t/nonexistent-token"

        expect(response).to redirect_to(root_path)
      end
    end

    context "TRK-006: tracking endpoints skip authentication" do
      it "works without authentication" do
        user = create(:user)
        episode = create(:episode)
        event = create(:email_event, :click_summary, user: user, episode: episode)

        # No sign_in_as — should still work
        get "/t/#{event.token}"

        expect(response).to have_http_status(:redirect)
      end
    end

    context "Security: no open redirect" do
      it "redirects to internal paths only" do
        user = create(:user)
        episode = create(:episode)
        event = create(:email_event, :click_summary, user: user, episode: episode)

        get "/t/#{event.token}"

        # Redirect location should be an internal path, not an external URL
        expect(response.location).to include(episode_path(episode))
        expect(response.location).not_to include("http://evil.com")
      end
    end

    context "with already triggered event" do
      it "still redirects successfully but does not update triggered_at" do
        user = create(:user)
        episode = create(:episode)
        original_time = 1.hour.ago
        event = create(:email_event, :click_summary, :triggered, user: user, episode: episode, triggered_at: original_time)

        get "/t/#{event.token}"

        expect(response).to redirect_to(episode_path(episode))
        expect(event.reload.triggered_at).to be_within(1.second).of(original_time)
      end
    end
  end

  describe "GET /t/:token/pixel.gif (open tracking)" do
    context "TRK-001: open tracking pixel" do
      let(:user) { create(:user) }
      let!(:event) { create(:email_event, :open, user: user) }

      it "returns a 1x1 transparent GIF" do
        get "/t/#{event.token}/pixel.gif"

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("image/gif")
      end

      it "records triggered_at on the event" do
        freeze_time do
          get "/t/#{event.token}/pixel.gif"

          expect(event.reload.triggered_at).to eq(Time.current)
        end
      end

      it "records user_agent on the event" do
        get "/t/#{event.token}/pixel.gif", headers: { "User-Agent" => "AppleMail/1.0" }

        expect(event.reload.user_agent).to eq("AppleMail/1.0")
      end
    end

    context "TRK-006: pixel always returns GIF regardless of token validity" do
      it "returns GIF for invalid token" do
        get "/t/nonexistent-token/pixel.gif"

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("image/gif")
      end
    end

    context "TRK-006: pixel works without authentication" do
      it "works without being signed in" do
        user = create(:user)
        event = create(:email_event, :open, user: user)

        # No sign_in_as
        get "/t/#{event.token}/pixel.gif"

        expect(response).to have_http_status(:success)
      end
    end
  end
end
