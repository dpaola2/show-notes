require "rails_helper"

RSpec.describe "Sessions UTM Attribution", type: :request do
  describe "TRK-004: UTM source persisted through signup flow" do
    context "when login page includes UTM params" do
      it "persists referral_source on new user during signup" do
        # Step 1: Visit login page with UTM params (from public page CTA)
        get login_path, params: { utm_source: "share" }

        # Step 2: Submit signup/login form
        post login_path, params: { email: "newuser@example.com" }

        # Step 3: Verify magic link
        user = User.find_by(email: "newuser@example.com")
        token = user.reload.magic_token
        get verify_magic_link_path(token: token)

        # Step 4: Check referral_source was persisted
        expect(user.reload.referral_source).to eq("share")
      end

      it "does not overwrite referral_source for returning users" do
        existing_user = create(:user, referral_source: "organic")

        get login_path, params: { utm_source: "share" }
        post login_path, params: { email: existing_user.email }

        expect(existing_user.reload.referral_source).to eq("organic")
      end
    end

    context "when login page has no UTM params" do
      it "leaves referral_source nil for new users" do
        post login_path, params: { email: "newuser@example.com" }

        user = User.find_by(email: "newuser@example.com")
        expect(user.referral_source).to be_nil
      end
    end

    context "UTM parameter sanitization" do
      it "only stores the utm_source value" do
        get login_path, params: {
          utm_source: "share",
          utm_medium: "social",
          utm_content: "episode_42"
        }
        post login_path, params: { email: "newuser@example.com" }

        user = User.find_by(email: "newuser@example.com")
        token = user.reload.magic_token
        get verify_magic_link_path(token: token)

        expect(user.reload.referral_source).to eq("share")
      end

      it "truncates excessively long utm_source values" do
        get login_path, params: { utm_source: "a" * 500 }
        post login_path, params: { email: "newuser@example.com" }

        user = User.find_by(email: "newuser@example.com")
        token = user.reload.magic_token
        get verify_magic_link_path(token: token)

        expect(user.reload.referral_source.length).to be <= 255
      end
    end
  end
end
