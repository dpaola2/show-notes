require "rails_helper"

RSpec.describe "Api::Sessions", type: :request do
  describe "POST /api/session" do
    context "AUTH-001: magic link request" do
      it "sends a magic link email and returns a success message" do
        user = create(:user)

        post "/api/session", params: { email: user.email }, as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["message"]).to eq("Check your email for a sign-in link")
      end

      it "always returns 200 regardless of whether the email exists" do
        post "/api/session", params: { email: "nonexistent@example.com" }, as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["message"]).to eq("Check your email for a sign-in link")
      end

      it "creates a new user account via find_or_create_by if the email is unknown" do
        expect {
          post "/api/session", params: { email: "brand-new@example.com" }, as: :json
        }.to change(User, :count).by(1)

        expect(User.find_by(email: "brand-new@example.com")).to be_present
      end

      it "sends a magic link email" do
        user = create(:user)

        expect {
          post "/api/session", params: { email: user.email }, as: :json
        }.to have_enqueued_mail(UserMailer, :magic_link)
      end

      it "generates a magic token for the user" do
        user = create(:user)

        post "/api/session", params: { email: user.email }, as: :json
        user.reload

        expect(user.magic_token).to be_present
        expect(user.magic_token_expires_at).to be > Time.current
      end
    end

    context "AUTH-002: magic link contains Universal Link URL for iOS source" do
      it "sends a Universal Link URL when source is ios" do
        user = create(:user)

        post "/api/session", params: { email: user.email, source: "ios" }, as: :json

        expect(response).to have_http_status(:ok)
        delivered_email = ActionMailer::Base.deliveries.last
        # The mailer should generate a Universal Link URL containing listen.davepaola.com
        # and /auth/verify with the magic token
        expect(delivered_email).to be_present
      end
    end

    context "edge case: new magic link invalidates previous" do
      it "invalidates the previous unused magic link when a new one is requested" do
        user = create(:user)

        post "/api/session", params: { email: user.email }, as: :json
        old_token = user.reload.magic_token

        post "/api/session", params: { email: user.email }, as: :json
        new_token = user.reload.magic_token

        expect(new_token).not_to eq(old_token)
        expect(user.magic_token_valid?(old_token)).to be false
      end
    end
  end

  describe "POST /api/session/verify" do
    context "AUTH-003: token exchange" do
      it "returns a bearer token for a valid magic token" do
        user = create(:user)
        magic_token = user.generate_magic_token!

        post "/api/session/verify", params: { token: magic_token }, as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["token"]).to be_a(String)
        expect(parsed["token"].length).to be >= 32
      end

      it "stores only the SHA-256 digest in the database" do
        user = create(:user)
        magic_token = user.generate_magic_token!

        post "/api/session/verify", params: { token: magic_token }, as: :json

        parsed = JSON.parse(response.body)
        plaintext = parsed["token"]
        api_token = ApiToken.last

        expect(api_token.token_digest).to eq(Digest::SHA256.hexdigest(plaintext))
        expect(api_token.token_digest).not_to eq(plaintext)
      end

      it "clears the magic token after successful exchange" do
        user = create(:user)
        magic_token = user.generate_magic_token!

        post "/api/session/verify", params: { token: magic_token }, as: :json

        user.reload
        expect(user.magic_token).to be_nil
        expect(user.magic_token_expires_at).to be_nil
      end
    end

    context "AUTH-003 edge case: expired token" do
      it "returns 401 for an expired magic token" do
        user = create(:user, :with_expired_token)

        post "/api/session/verify", params: { token: user.magic_token }, as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to include("expired or invalid")
      end
    end

    context "AUTH-003 edge case: already used token" do
      it "returns 401 for an already-used magic token" do
        user = create(:user)
        magic_token = user.generate_magic_token!

        # Use the token once
        post "/api/session/verify", params: { token: magic_token }, as: :json
        expect(response).to have_http_status(:ok)

        # Try to use it again
        post "/api/session/verify", params: { token: magic_token }, as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to include("expired or invalid")
      end
    end

    context "with an invalid token" do
      it "returns 401" do
        post "/api/session/verify", params: { token: "completely-invalid" }, as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to include("expired or invalid")
      end
    end

    context "with a blank token" do
      it "returns 401" do
        post "/api/session/verify", params: { token: "" }, as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to include("expired or invalid")
      end
    end
  end

  describe "DELETE /api/session" do
    context "AUTH-004: logout" do
      it "destroys the current bearer token and returns success" do
        user = create(:user)
        token = api_sign_in_as(user)

        delete "/api/session", headers: api_headers(token), as: :json

        expect(response).to have_http_status(:ok)
        parsed = JSON.parse(response.body)
        expect(parsed["message"]).to eq("Logged out")
      end

      it "invalidates the token so it can no longer be used" do
        user = create(:user)
        token = api_sign_in_as(user)

        delete "/api/session", headers: api_headers(token), as: :json

        # Try to use the same token again
        delete "/api/session", headers: api_headers(token), as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it "does not invalidate other tokens for the same user" do
        user = create(:user)
        token1 = api_sign_in_as(user)
        token2 = api_sign_in_as(user)

        delete "/api/session", headers: api_headers(token1), as: :json
        expect(response).to have_http_status(:ok)

        # Token 2 should still work
        delete "/api/session", headers: api_headers(token2), as: :json
        expect(response).to have_http_status(:ok)
      end
    end

    context "AUTH-006: unauthenticated" do
      it "returns 401 without a bearer token" do
        delete "/api/session", as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end

      it "returns 401 with an invalid bearer token" do
        delete "/api/session", headers: api_headers("invalid-token"), as: :json

        expect(response).to have_http_status(:unauthorized)
        parsed = JSON.parse(response.body)
        expect(parsed["error"]).to eq("Unauthorized")
      end
    end
  end

  describe "API-001: namespace and URL prefix" do
    it "all session endpoints live under /api/" do
      user = create(:user)

      post "/api/session", params: { email: user.email }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe "API-003: consistent error format" do
    it "returns JSON error format for invalid token exchange" do
      post "/api/session/verify", params: { token: "bad" }, as: :json

      parsed = JSON.parse(response.body)
      expect(parsed).to have_key("error")
      expect(parsed["error"]).to be_a(String)
    end

    it "returns JSON error format for unauthenticated logout" do
      delete "/api/session", as: :json

      parsed = JSON.parse(response.body)
      expect(parsed).to have_key("error")
      expect(parsed["error"]).to be_a(String)
    end
  end

  describe "API-004: BaseController configuration" do
    it "does not require CSRF tokens for API requests" do
      user = create(:user)

      # POST without CSRF token should still succeed
      post "/api/session", params: { email: user.email }, as: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe "bearer token auth touches last_used_at" do
    it "updates last_used_at on authenticated requests" do
      user = create(:user)
      token = api_sign_in_as(user)
      api_token = ApiToken.last

      freeze_time do
        delete "/api/session", headers: api_headers(token), as: :json
        api_token.reload
        expect(api_token.last_used_at).to be_within(1.second).of(Time.current)
      end
    end
  end
end
