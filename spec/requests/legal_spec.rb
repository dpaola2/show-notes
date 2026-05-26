require "rails_helper"

RSpec.describe "Legal pages", type: :request do
  describe "GET /privacy" do
    it "renders successfully without authentication" do
      get "/privacy"

      expect(response).to have_http_status(:success)
    end

    it "does not redirect to login" do
      get "/privacy"

      expect(response).not_to redirect_to(login_path)
    end

    it "includes the page heading" do
      get "/privacy"

      expect(response.body).to include("Privacy Policy")
    end

    it "discloses the third-party processors named in the App Store privacy declarations" do
      get "/privacy"

      expect(response.body).to include("AssemblyAI")
      expect(response.body).to include("Anthropic")
      expect(response.body).to include("Resend")
    end

    it "provides a contact email" do
      get "/privacy"

      expect(response.body).to include("dpaola2@gmail.com")
    end
  end

  describe "GET /support" do
    it "renders successfully without authentication" do
      get "/support"

      expect(response).to have_http_status(:success)
    end

    it "does not redirect to login" do
      get "/support"

      expect(response).not_to redirect_to(login_path)
    end

    it "includes the page heading" do
      get "/support"

      expect(response.body).to include("Support")
    end

    it "provides a contact email" do
      get "/support"

      expect(response.body).to include("dpaola2@gmail.com")
    end

    it "links to the privacy policy" do
      get "/support"

      expect(response.body).to include(privacy_path)
    end
  end
end
