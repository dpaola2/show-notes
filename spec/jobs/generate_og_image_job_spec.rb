require "rails_helper"

RSpec.describe GenerateOgImageJob, type: :job do
  include ActiveJob::TestHelper

  let(:podcast) { create(:podcast, title: "Test Podcast", artwork_url: "https://example.com/artwork.jpg") }
  let(:episode) { create(:episode, podcast: podcast, title: "Test Episode") }
  let!(:summary) do
    create(:summary, episode: episode, quotes: [
      { "text" => "A great quote.", "start_time" => 120, "end_time" => 128 }
    ])
  end

  # Minimal valid PNG for stubbing
  let(:minimal_png) do
    [137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
     0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0,
     0, 0, 10, 73, 68, 65, 84, 120, 156, 98, 0, 0, 0, 2, 0, 1, 226,
     33, 188, 51, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130].pack("C*")
  end

  before do
    stub_request(:get, "https://example.com/artwork.jpg")
      .to_return(body: minimal_png, status: 200, headers: { "Content-Type" => "image/png" })
  end

  describe "#perform" do
    context "OGI-008: triggered after summary creation" do
      it "attaches an OG image to the episode" do
        described_class.perform_now(episode.id)

        expect(episode.reload.og_image).to be_attached
      end

      it "attaches a PNG image" do
        described_class.perform_now(episode.id)

        expect(episode.reload.og_image.content_type).to eq("image/png")
      end
    end

    context "artwork fetch failure" do
      before do
        stub_request(:get, "https://example.com/artwork.jpg")
          .to_return(status: 500)
      end

      it "still generates an OG image using placeholder artwork" do
        described_class.perform_now(episode.id)

        expect(episode.reload.og_image).to be_attached
      end
    end

    context "missing artwork URL" do
      before do
        podcast.update!(artwork_url: nil)
      end

      it "generates an OG image using placeholder artwork" do
        described_class.perform_now(episode.id)

        expect(episode.reload.og_image).to be_attached
      end
    end

    context "episode without summary" do
      let(:episode_no_summary) { create(:episode, podcast: podcast) }

      it "does not generate an OG image" do
        described_class.perform_now(episode_no_summary.id)

        expect(episode_no_summary.reload.og_image).not_to be_attached
      end
    end

    context "OG image generation failure does not break things" do
      before do
        allow(OgImageGenerator).to receive(:generate).and_raise(StandardError, "vips error")
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(/OG image generation failed/)

        described_class.perform_now(episode.id)
      end

      it "does not raise" do
        expect {
          described_class.perform_now(episode.id)
        }.not_to raise_error
      end
    end

    context "replaces existing OG image on regeneration" do
      it "replaces the old OG image when regenerated" do
        described_class.perform_now(episode.id)
        first_blob_id = episode.reload.og_image.blob.id

        described_class.perform_now(episode.id)
        second_blob_id = episode.reload.og_image.blob.id

        expect(second_blob_id).not_to eq(first_blob_id)
      end
    end
  end

  describe "OGI-008: enqueued from ProcessEpisodeJob" do
    let(:user) { create(:user) }
    let!(:user_episode) { create(:user_episode, user: user, episode: episode, processing_status: :summarizing) }

    before do
      # Stub external services used by ProcessEpisodeJob
      allow(AssemblyAiClient).to receive(:transcribe).and_return({ "segments" => [] })
      allow(ClaudeClient).to receive(:summarize_chunked).and_return({
        "sections" => [{ "title" => "Summary", "content" => "Content." }],
        "quotes" => [{ "text" => "A quote.", "start_time" => 0, "end_time" => 5 }]
      })
      create(:transcript, episode: episode)
    end

    it "enqueues GenerateOgImageJob after creating a summary" do
      expect {
        ProcessEpisodeJob.perform_now(user_episode.id)
      }.to have_enqueued_job(GenerateOgImageJob)
    end
  end
end
