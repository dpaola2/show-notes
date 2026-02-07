require "rails_helper"

RSpec.describe "Signup Notifications", type: :request do
  describe "POST /login" do
    context "with a new user" do
      it "enqueues a signup notification email" do
        expect {
          post login_path, params: { email: "brand-new@example.com" }
        }.to have_enqueued_mail(SignupNotificationMailer, :new_signup)
      end
    end

    context "with an existing user" do
      let!(:user) { create(:user, email: "returning@example.com") }

      it "does not enqueue a signup notification email" do
        expect {
          post login_path, params: { email: "returning@example.com" }
        }.not_to have_enqueued_mail(SignupNotificationMailer, :new_signup)
      end
    end
  end
end
