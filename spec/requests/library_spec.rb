require "rails_helper"

RSpec.describe "Library", type: :request do
  let!(:user) { create(:user) }

  before do
    sign_in_as(user)
  end

  describe "GET /library" do
    it "renders the library page" do
      get library_index_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Library")
    end

    context "with pagination" do
      let(:podcast) { create(:podcast) }

      before do
        25.times do |i|
          episode = create(:episode, podcast: podcast, title: "Lib Episode #{i.to_s.rjust(2, '0')}", published_at: i.days.ago)
          create(:user_episode, user: user, episode: episode, location: :library)
        end
      end

      it "returns only the first page of results" do
        get library_index_path

        expect(response.body).to include("Lib Episode 00") # most recent
        expect(response.body).not_to include("Lib Episode 24") # oldest, on page 2
      end

      it "renders pagination nav" do
        get library_index_path

        expect(response.body).to include("pagy")
      end

      it "returns the second page when requested" do
        get library_index_path, params: { page: 2 }

        expect(response.body).to include("Lib Episode 24") # oldest, on page 2
        expect(response.body).not_to include("Lib Episode 00") # most recent, on page 1
      end

      it "does not render pagination when items fit on one page" do
        user.user_episodes.in_library.limit(10).destroy_all

        get library_index_path

        expect(response.body).not_to include("series-nav")
      end
    end

    context "with empty library" do
      it "shows empty state message" do
        get library_index_path

        expect(response.body).to include("Your library is empty")
      end
    end
  end
end
