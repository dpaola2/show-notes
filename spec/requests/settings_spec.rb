require "rails_helper"

RSpec.describe "Settings", type: :request do
  let!(:user) { create(:user, digest_enabled: true) }

  before do
    sign_in_as(user)
  end

  describe "GET /settings" do
    it "renders the settings page" do
      get settings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Settings")
    end

    it "shows email preferences section" do
      get settings_path

      expect(response.body).to include("Email Preferences")
      expect(response.body).to include("Daily Digest Email")
    end

    it "shows the current digest_enabled state" do
      get settings_path

      expect(response.body).to include("digest_enabled")
    end

    it "shows account section with email" do
      get settings_path

      expect(response.body).to include("Account")
      expect(response.body).to include(user.email)
    end

    context "when digest was sent previously" do
      before do
        user.update!(digest_sent_at: 1.day.ago)
      end

      it "shows last digest sent time" do
        get settings_path

        expect(response.body).to include("Last digest sent")
      end
    end
  end

  describe "PATCH /settings" do
    it "updates digest_enabled to false" do
      expect {
        patch settings_path, params: { user: { digest_enabled: false } }
      }.to change { user.reload.digest_enabled }.from(true).to(false)

      expect(response).to redirect_to(settings_path)
      follow_redirect!
      expect(response.body).to include("Settings saved")
    end

    it "updates digest_enabled to true" do
      user.update!(digest_enabled: false)

      expect {
        patch settings_path, params: { user: { digest_enabled: true } }
      }.to change { user.reload.digest_enabled }.from(false).to(true)
    end

    it "does not allow updating other fields" do
      original_email = user.email

      patch settings_path, params: { user: { email: "hacker@evil.com" } }

      expect(user.reload.email).to eq(original_email)
    end
  end
end
