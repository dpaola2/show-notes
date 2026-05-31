require "rails_helper"

RSpec.describe "Onboarding", type: :request do
  describe "GET /onboarding" do
    it "renders the connect-your-shows step for a signed-in user" do
      user = create(:user)
      sign_in(user)

      get onboarding_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Connect your shows")
      expect(response.body).to include(new_import_path)
      expect(response.body).to include(podcasts_path)
    end

    it "requires authentication" do
      get onboarding_path
      expect(response).to redirect_to(login_path)
    end
  end
end
