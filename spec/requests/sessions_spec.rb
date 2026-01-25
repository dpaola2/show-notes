require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "GET /login" do
    it "renders the login form" do
      get login_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Welcome to Show Notes")
      expect(response.body).to include("Email address")
    end
  end

  describe "POST /login" do
    context "with a valid email" do
      it "creates a user if they don't exist" do
        expect {
          post login_path, params: { email: "new@example.com" }
        }.to change(User, :count).by(1)
      end

      it "generates a magic token" do
        user = create(:user)

        post login_path, params: { email: user.email }
        user.reload

        expect(user.magic_token).to be_present
        expect(user.magic_token_expires_at).to be > Time.current
      end

      it "sends a magic link email" do
        user = create(:user)

        expect {
          post login_path, params: { email: user.email }
        }.to have_enqueued_mail(UserMailer, :magic_link)
      end

      it "redirects to the sent page" do
        post login_path, params: { email: "test@example.com" }

        expect(response).to redirect_to(magic_link_sent_path)
      end

      it "normalizes the email address" do
        post login_path, params: { email: "  TEST@Example.COM  " }

        expect(User.last.email).to eq("test@example.com")
      end
    end

    context "with a blank email" do
      it "renders the login form with an error" do
        post login_path, params: { email: "" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Please enter your email address")
      end
    end

    context "with an invalid email format" do
      it "renders the login form with an error" do
        post login_path, params: { email: "not-an-email" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Invalid email address")
      end
    end
  end

  describe "GET /login/sent" do
    it "renders the check your email page" do
      get magic_link_sent_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Check your email")
      expect(response.body).to include("magic link")
    end
  end

  describe "GET /auth/verify" do
    let(:user) { create(:user) }
    let(:token) { user.generate_magic_token! }

    context "with a valid token" do
      it "signs the user in" do
        get verify_magic_link_path(token: token)

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Welcome back!")
      end

      it "clears the magic token" do
        get verify_magic_link_path(token: token)
        user.reload

        expect(user.magic_token).to be_nil
        expect(user.magic_token_expires_at).to be_nil
      end

      it "sets the session" do
        get verify_magic_link_path(token: token)

        # Verify we're logged in by accessing a protected page
        get inbox_index_path
        expect(response).to have_http_status(:success)
      end
    end

    context "with an expired token" do
      before do
        token # generate token
        user.update!(magic_token_expires_at: 1.hour.ago)
      end

      it "redirects to login with an error" do
        get verify_magic_link_path(token: token)

        expect(response).to redirect_to(login_path)
        follow_redirect!
        expect(response.body).to include("expired or is invalid")
      end
    end

    context "with an invalid token" do
      it "redirects to login with an error" do
        get verify_magic_link_path(token: "invalid-token")

        expect(response).to redirect_to(login_path)
        follow_redirect!
        expect(response.body).to include("expired or is invalid")
      end
    end

    context "with a blank token" do
      it "redirects to login with an error" do
        get verify_magic_link_path(token: "")

        expect(response).to redirect_to(login_path)
        follow_redirect!
        expect(response.body).to include("Invalid or missing token")
      end
    end
  end

  describe "DELETE /logout" do
    let(:user) { create(:user) }

    before do
      sign_in(user)
    end

    it "signs the user out" do
      delete logout_path

      expect(response).to redirect_to(login_path)
      follow_redirect!
      expect(response.body).to include("logged out")
    end

    it "requires login after signing out" do
      delete logout_path

      get inbox_index_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "authentication requirement" do
    it "redirects unauthenticated users to login" do
      get inbox_index_path

      expect(response).to redirect_to(login_path)
    end

    it "shows an alert message" do
      get inbox_index_path

      follow_redirect!
      expect(response.body).to include("Please sign in to continue")
    end
  end
end
