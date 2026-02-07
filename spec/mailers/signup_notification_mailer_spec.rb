require "rails_helper"

RSpec.describe SignupNotificationMailer, type: :mailer do
  describe "#new_signup" do
    let(:user) { create(:user, email: "newuser@example.com") }
    let(:mail) { SignupNotificationMailer.new_signup(user) }

    it "sends to the configured recipients" do
      expect(mail.to).to match_array([
        "dpaola2@gmail.com",
        "dpaola2-ceo@agentmail.to"
      ])
    end

    it "has the correct subject with user email" do
      expect(mail.subject).to eq("New Show Notes signup: newuser@example.com")
    end

    it "sends from the default sender" do
      expect(mail.from).to include("noreply@listen.davepaola.com")
    end

    it "includes the user email in the HTML body" do
      expect(mail.html_part.body).to include("newuser@example.com")
    end

    it "includes the signup timestamp in the HTML body" do
      expect(mail.html_part.body).to include(user.created_at.strftime("%B %d, %Y"))
    end

    it "includes the user email in the text body" do
      expect(mail.text_part.body).to include("newuser@example.com")
    end

    it "includes the signup timestamp in the text body" do
      expect(mail.text_part.body).to include(user.created_at.strftime("%B %d, %Y"))
    end
  end
end
