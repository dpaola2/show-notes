require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "#magic_link with source parameter" do
    let(:user) { create(:user) }
    let(:token) { user.generate_magic_token! }

    context "AUTH-002: source :ios generates Universal Link URL" do
      it "includes the Universal Link URL for iOS" do
        mail = described_class.magic_link(user, token, source: :ios)

        expect(mail.body.encoded).to include("listen.davepaola.com")
        expect(mail.body.encoded).to include("/auth/verify")
        expect(mail.body.encoded).to include(token)
      end

      it "uses https scheme for Universal Link" do
        mail = described_class.magic_link(user, token, source: :ios)

        expect(mail.body.encoded).to include("https://listen.davepaola.com")
      end
    end

    context "AUTH-002 backwards compat: source defaults to :web" do
      it "uses the standard verify_magic_link_url when source is not specified" do
        mail = described_class.magic_link(user, token)

        # The existing web URL pattern should be preserved
        expect(mail.body.encoded).to include("auth/verify")
        expect(mail.body.encoded).to include(token)
      end

      it "uses the standard verify_magic_link_url when source is :web" do
        mail = described_class.magic_link(user, token, source: :web)

        expect(mail.body.encoded).to include("auth/verify")
        expect(mail.body.encoded).to include(token)
      end
    end
  end
end
