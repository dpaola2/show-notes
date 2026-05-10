require "rails_helper"
require "rake"

# Lightweight task spec for SN-17 / M5 — QA seed rake tasks under library-drip.
# Asserts each of the three rake tasks runs without raising and produces the
# expected scenario data (eligible UserEpisodes for the new digest model).
#
# Per the gameplan, the tasks must:
# - run to completion without referencing `digest_sent_at: 25.hours.ago`
# - seed UserEpisodes covering happy/exhausted/mixed/edge scenarios
# - be idempotent (re-runs do not duplicate users/podcasts/UserEpisodes)
RSpec.describe "QA seed rake tasks under library-drip", type: :task do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  before do
    # Reinstate task so :invoke can be called multiple times (RSpec runs each example fresh).
    %w[
      seed_digest_qa
      qa_seed
      pipeline:library_scoped_processing_qa
    ].each do |task_name|
      Rake::Task[task_name].reenable if Rake::Task.task_defined?(task_name)
    end
  end

  shared_examples "a library-drip QA seed task" do |task_name|
    it "runs without raising under the library-drip data model" do
      expect { Rake::Task[task_name].invoke }.not_to raise_error
    end

    it "creates at least one UserEpisode with digest_featured_at = nil (eligible scenario)" do
      Rake::Task[task_name].invoke

      eligible_count = UserEpisode
        .where(location: UserEpisode.locations[:library],
               processing_status: UserEpisode.processing_statuses[:ready],
               digest_featured_at: nil)
        .count

      expect(eligible_count).to be > 0
    end

    it "creates at least one user with digest_enabled = true" do
      Rake::Task[task_name].invoke

      expect(User.where(digest_enabled: true).count).to be > 0
    end

    it "is idempotent — re-running does not duplicate users" do
      Rake::Task[task_name].invoke
      first_user_count = User.count

      Rake::Task[task_name].reenable
      Rake::Task[task_name].invoke

      expect(User.count).to eq(first_user_count)
    end

    it "is idempotent — re-running does not duplicate UserEpisodes" do
      Rake::Task[task_name].invoke
      first_ue_count = UserEpisode.count

      Rake::Task[task_name].reenable
      Rake::Task[task_name].invoke

      expect(UserEpisode.count).to eq(first_ue_count)
    end
  end

  describe "seed_digest_qa" do
    it_behaves_like "a library-drip QA seed task", "seed_digest_qa"
  end

  describe "qa_seed" do
    it_behaves_like "a library-drip QA seed task", "qa_seed"
  end

  describe "pipeline:library_scoped_processing_qa" do
    it_behaves_like "a library-drip QA seed task", "pipeline:library_scoped_processing_qa"

    it "keeps the legacy filename (per GP-2) — no rename" do
      expected_path = Rails.root.join("lib/tasks/pipeline/library_scoped_processing_qa.rake")
      expect(File.exist?(expected_path)).to be(true)
    end
  end
end
