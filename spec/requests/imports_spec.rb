require "rails_helper"

RSpec.describe "Imports", type: :request do
  let!(:user) { create(:user) }

  before do
    sign_in_as(user)
  end

  describe "GET /import/new" do
    context "IMP-001: user can initiate import" do
      it "renders the upload form" do
        get new_import_path

        expect(response).to have_http_status(:success)
      end

      it "IMP-002: shows generic export instructions" do
        get new_import_path

        expect(response.body).to include("Export your OPML file")
        expect(response.body).to include("upload")
      end
    end

    context "when user has existing subscriptions" do
      before do
        podcast = create(:podcast)
        create(:subscription, user: user, podcast: podcast)
      end

      it "is still accessible" do
        get new_import_path

        expect(response).to have_http_status(:success)
      end
    end

    context "when not authenticated" do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it "redirects to login" do
        get new_import_path

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /import" do
    let(:valid_opml) { file_fixture("valid_podcasts.opml") }
    let(:empty_feeds_opml) { file_fixture("empty_feeds.opml") }

    context "IMP-003/IMP-004: uploading a valid OPML file" do
      it "subscribes to all feeds and renders the favorites selection" do
        post import_path, params: { opml_file: fixture_file_upload("valid_podcasts.opml", "text/xml") }

        expect(response).to have_http_status(:success)
      end

      it "SUB-001: creates Podcast and Subscription records" do
        expect {
          post import_path, params: { opml_file: fixture_file_upload("valid_podcasts.opml", "text/xml") }
        }.to change(Subscription, :count).by(3)
      end

      it "IMP-006: displays the count of discovered podcasts" do
        post import_path, params: { opml_file: fixture_file_upload("valid_podcasts.opml", "text/xml") }

        expect(response.body).to include("3") # "We found 3 podcasts!"
      end

      it "IMP-005: displays podcast names in the response" do
        post import_path, params: { opml_file: fixture_file_upload("valid_podcasts.opml", "text/xml") }

        expect(response.body).to include("The Daily")
        expect(response.body).to include("Acquired")
        expect(response.body).to include("Hardcore History")
      end

      it "FAV-001: renders checkboxes for podcast selection" do
        post import_path, params: { opml_file: fixture_file_upload("valid_podcasts.opml", "text/xml") }

        expect(response.body).to include("podcast_ids")
      end

      it "FAV-003: shows the recommended range hint" do
        post import_path, params: { opml_file: fixture_file_upload("valid_podcasts.opml", "text/xml") }

        expect(response.body).to match(/5.?10/i) # "Pick 5-10 of your favorites"
      end

      it "PRC-002: displays cost estimate" do
        post import_path, params: { opml_file: fixture_file_upload("valid_podcasts.opml", "text/xml") }

        # Flat $0.46/episode cost estimate should appear somewhere
        expect(response.body).to include("0.46")
      end
    end

    context "IMP-006: re-import shows already-subscribed count" do
      before do
        # Pre-existing subscription for one of the OPML feeds
        podcast = create(:podcast, feed_url: "https://feeds.simplecast.com/the-daily", guid: "existing-guid")
        create(:subscription, user: user, podcast: podcast)
      end

      it "shows how many were already subscribed" do
        post import_path, params: { opml_file: fixture_file_upload("valid_podcasts.opml", "text/xml") }

        expect(response).to have_http_status(:success)
        expect(response.body).to include("already")
      end
    end

    context "IMP-007: uploading a malformed file" do
      it "redirects back with an error flash" do
        post import_path, params: { opml_file: fixture_file_upload("empty_feeds.opml", "text/xml") }

        expect(response).to redirect_to(new_import_path)
        follow_redirect!
        expect(response.body).to include("podcast feeds")
      end
    end

    context "when no file is attached" do
      it "redirects back with an error flash" do
        post import_path, params: {}

        expect(response).to redirect_to(new_import_path)
      end
    end

    context "when not authenticated" do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it "redirects to login" do
        post import_path, params: { opml_file: fixture_file_upload("valid_podcasts.opml", "text/xml") }

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /import/process_favorites" do
    let!(:podcast1) { create(:podcast, feed_url: "https://feeds.example.com/one") }
    let!(:podcast2) { create(:podcast, feed_url: "https://feeds.example.com/two") }

    let(:episode_struct) do
      PodcastFeedParser::Episode.new(
        guid: "latest-ep-guid",
        title: "Latest Episode",
        description: "Desc",
        audio_url: "https://example.com/latest.mp3",
        duration_seconds: 3600,
        published_at: 1.day.ago
      )
    end

    before do
      create(:subscription, user: user, podcast: podcast1)
      create(:subscription, user: user, podcast: podcast2)

      allow(PodcastFeedParser).to receive(:parse).and_return([episode_struct])
    end

    context "PRC-001/PRC-003: processing selected favorites" do
      it "redirects to the complete page" do
        post process_favorites_imports_path, params: { podcast_ids: [podcast1.id] }

        expect(response).to redirect_to(complete_imports_path)
      end

      it "enqueues ProcessEpisodeJob for selected podcasts" do
        expect {
          post process_favorites_imports_path, params: { podcast_ids: [podcast1.id, podcast2.id] }
        }.to have_enqueued_job(ProcessEpisodeJob).twice
      end
    end

    context "FAV-002: with empty selection" do
      it "redirects back with an error when no podcasts are selected" do
        post process_favorites_imports_path, params: { podcast_ids: [] }

        expect(response).to redirect_to(new_import_path)
      end

      it "redirects back when podcast_ids param is missing entirely" do
        post process_favorites_imports_path, params: {}

        expect(response).to redirect_to(new_import_path)
      end
    end

    context "when not authenticated" do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it "redirects to login" do
        post process_favorites_imports_path, params: { podcast_ids: [podcast1.id] }

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "GET /import/complete" do
    context "PRC-004: confirmation page" do
      it "renders the confirmation page" do
        get complete_imports_path

        expect(response).to have_http_status(:success)
      end

      it "shows the digest promise message" do
        get complete_imports_path

        expect(response.body).to include("digest")
        expect(response.body).to include("tomorrow")
      end

      it "includes a link back to the dashboard" do
        get complete_imports_path

        expect(response.body).to include(root_path)
      end
    end

    context "when not authenticated" do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      end

      it "redirects to login" do
        get complete_imports_path

        expect(response).to redirect_to(root_path)
      end
    end
  end
end
