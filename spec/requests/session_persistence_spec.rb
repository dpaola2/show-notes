require "rails_helper"

RSpec.describe "Session Persistence", type: :request do
  let(:user) { create(:user) }
  let(:podcast) { create(:podcast) }
  let!(:subscription) { create(:subscription, user: user, podcast: podcast) }
  let(:episode) { create(:episode, podcast: podcast) }

  describe "return-to URL after authentication" do
    context "when visiting a protected page without a session" do
      it "redirects to login" do
        get episode_path(episode)

        expect(response).to redirect_to(login_path)
      end

      it "stores the requested URL in the session" do
        get episode_path(episode)

        # After redirect to login, the session should contain the return-to URL
        # We verify this by completing the auth flow and checking the final redirect
        post login_path, params: { email: user.email }
        token = user.reload.magic_token

        get verify_magic_link_path(token: token)

        expect(response).to redirect_to(episode_path(episode))
      end

      it "redirects to root when no return-to URL is stored" do
        # Go directly to login (not redirected from a protected page)
        post login_path, params: { email: user.email }
        token = user.reload.magic_token

        get verify_magic_link_path(token: token)

        expect(response).to redirect_to(root_path)
      end

      it "clears the return-to URL after redirect to prevent stale redirects" do
        # First login: redirected from episode page
        get episode_path(episode)
        post login_path, params: { email: user.email }
        token = user.reload.magic_token
        get verify_magic_link_path(token: token)

        expect(response).to redirect_to(episode_path(episode))

        # Logout
        delete logout_path

        # Second login: go directly to login (no prior protected page visit)
        post login_path, params: { email: user.email }
        token = user.reload.magic_token
        get verify_magic_link_path(token: token)

        # Should go to root, not the stale episode URL
        expect(response).to redirect_to(root_path)
      end
    end

    context "when the original request is not a GET" do
      it "does not store the return-to URL for POST requests" do
        # Attempt a POST to a protected endpoint without auth
        post inbox_index_path

        expect(response).to redirect_to(login_path)

        # Now authenticate
        post login_path, params: { email: user.email }
        token = user.reload.magic_token
        get verify_magic_link_path(token: token)

        # Should redirect to root, not replay the POST URL
        expect(response).to redirect_to(root_path)
      end

      it "does not store the return-to URL for DELETE requests" do
        sign_in(user)
        delete logout_path

        expect(response).to redirect_to(login_path)

        # Authenticate again
        post login_path, params: { email: user.email }
        token = user.reload.magic_token
        get verify_magic_link_path(token: token)

        # Should redirect to root
        expect(response).to redirect_to(root_path)
      end
    end

    context "digest email link flow" do
      let!(:email_event) do
        create(:email_event, :click_summary, user: user, episode: episode)
      end

      it "redirects back to the episode after authenticating from a tracking link" do
        # Click tracking link (no auth required)
        get tracking_click_path(token: email_event.token)

        # Tracking redirects to episode page
        expect(response).to redirect_to(episode_path(episode))

        # Follow redirect — hits auth wall (no session)
        follow_redirect!
        expect(response).to redirect_to(login_path)

        # Authenticate via magic link
        post login_path, params: { email: user.email }
        token = user.reload.magic_token
        get verify_magic_link_path(token: token)

        # Should redirect back to the episode, not root
        expect(response).to redirect_to(episode_path(episode))
      end

      it "lands directly on episode when already authenticated" do
        sign_in(user)

        # Click tracking link
        get tracking_click_path(token: email_event.token)

        # Tracking redirects to episode page
        expect(response).to redirect_to(episode_path(episode))

        # Follow redirect — should succeed (session active)
        follow_redirect!
        expect(response).to have_http_status(:success)
        expect(response.body).to include(episode.title)
      end
    end
  end

  describe "session cookie configuration" do
    it "maintains session across multiple requests after authentication" do
      sign_in(user)

      # Access multiple protected pages
      get inbox_index_path
      expect(response).to have_http_status(:success)

      get settings_path
      expect(response).to have_http_status(:success)

      get inbox_index_path
      expect(response).to have_http_status(:success)
    end

    it "session is destroyed after logout" do
      sign_in(user)

      get inbox_index_path
      expect(response).to have_http_status(:success)

      delete logout_path

      get inbox_index_path
      expect(response).to redirect_to(login_path)
    end
  end
end
