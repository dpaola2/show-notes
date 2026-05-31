require "rails_helper"

RSpec.describe "Landing", type: :request do
  describe "GET / (logged out)" do
    it "renders the public landing page" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Read your podcasts.")
      expect(response.body).to include("Get my first digest")
      # The CTA posts to the real magic-link signup flow
      expect(response.body).to include("action=\"#{login_path}\"")
    end

    it "does not require authentication" do
      get root_path
      expect(response).not_to redirect_to(login_path)
    end
  end

  describe "GET / (logged in)" do
    it "redirects to the inbox" do
      user = create(:user)
      sign_in(user)

      get root_path
      expect(response).to redirect_to(inbox_index_path)
    end
  end

  describe "the landing CTA drives the signup flow" do
    it "submitting the email sends a magic link" do
      expect {
        post login_path, params: { email: "lead@example.com" }
      }.to change(User, :count).by(1)

      expect(response).to redirect_to(magic_link_sent_path)
    end
  end
end
