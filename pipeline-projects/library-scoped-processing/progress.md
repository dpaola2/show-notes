---
pipeline_stage: 5
pipeline_stage_name: implementation
pipeline_project: "library-scoped-processing"
pipeline_m1_started_at: "2026-02-17T09:58:46-0500"
pipeline_m1_completed_at: "2026-02-17T10:03:51-0500"
pipeline_m2_started_at: "2026-02-17T10:07:23-0500"
pipeline_m2_completed_at: "2026-02-17T10:10:53-0500"
pipeline_m3_started_at: "2026-02-17T10:14:40-0500"
pipeline_m3_completed_at: "2026-02-17T10:16:28-0500"
---

# Implementation Progress — library-scoped-processing

| Field | Value |
|-------|-------|
| **Branch** | `pipeline/library-scoped-processing` |
| **Primary repo** | `/Users/dave/projects/show-notes` |
| **Milestones** | M0–M4 |

## Milestone Status

| Milestone | Description | Status |
|-----------|-------------|--------|
| M0 | Discovery & Alignment | Complete (Stages 1-3) |
| M1 | Shared Scope & Digest Query Change | **Complete** |
| M2 | Remove Auto-Processing from Feed Fetch | **Complete** |
| M3 | QA Test Data | **Complete** |
| M4 | Edge Cases & Polish | Pending |

---

## M1: Shared Scope & Digest Query Change

**Status:** Complete
**Date:** 2026-02-17
**Commit:** `b65d265`

### Files Created
- None

### Files Modified
- `app/models/episode.rb` — Added `library_ready_since` scope (joins user_episodes + podcast, filters by library location, ready status, updated_at)
- `app/mailers/digest_mailer.rb` — Replaced subscription query with `Episode.library_ready_since` in both class method and instance fallback; updated `since` calculation to 24-hour cap; changed subject line to library-centric copy
- `app/jobs/send_daily_digest_job.rb` — Replaced `has_new_episodes?` with `Episode.library_ready_since(user, since).exists?` using 24-hour cap
- `app/views/digest_mailer/daily_digest.html.erb` — Changed heading to "Your library", updated episode count format to "N episode(s) ready"
- `app/views/digest_mailer/daily_digest.text.erb` — Same copy changes as HTML template
- `CLAUDE.md` — Updated SendDailyDigestJob description from "subscription-based" to "library-scoped"

### Test Results
- **This milestone tests:** 33 passing, 0 failing
- **Prior milestone tests:** N/A (first milestone)
- **Future milestone tests:** 5 failing (expected — M2 tests for TRX-001, TRX-004)

### Acceptance Criteria
- [x] DIG-001: Digest email queries `user_episodes` in library location (not all subscription episodes)
- [x] DIG-002: Digest only includes library episodes with `processing_status=ready` whose `updated_at` is after `[digest_sent_at, 24.hours.ago].compact.max`
- [x] DIG-003: Digest subject line and email body copy reflect library-centric framing
- [x] DIG-004: If no library episodes match the eligibility window, `NullMail` is returned
- [x] `Episode.library_ready_since(user, since)` scope exists on `Episode` model
- [x] `SendDailyDigestJob#has_new_episodes?` uses `Episode.library_ready_since` with 24-hour cap
- [x] The `since` race protection pattern is preserved
- [x] Both DigestMailer query sites use the shared scope identically

### Spec Gaps
None

### Notes
- No new conventions discovered beyond the CLAUDE.md update (subscription-based → library-scoped).
- The scope uses `joins(:user_episodes, :podcast)` for SQL joins and `.includes(:summary)` for preloading — matching the original pattern from the codebase.

---

## M2: Remove Auto-Processing from Feed Fetch

**Status:** Complete
**Date:** 2026-02-17
**Commit:** `67e0c25`

### Files Created
- None

### Files Modified
- `app/jobs/fetch_podcast_feed_job.rb` — Removed `AutoProcessEpisodeJob.perform_later` call (lines 34-35)
- `app/jobs/detect_stuck_processing_job.rb` — Removed Episode stuck detection block (lines 19-29)
- `spec/jobs/fetch_podcast_feed_job_spec.rb` — Removed AutoProcessEpisodeJob assertions from pre-existing tests
- `spec/jobs/detect_stuck_processing_job_spec.rb` — Removed Episode stuck detection tests from pre-existing tests
- `CLAUDE.md` — Updated Background Jobs section (removed AutoProcessEpisodeJob, updated FetchPodcastFeedJob and DetectStuckProcessingJob descriptions)

### Files Deleted
- `app/jobs/auto_process_episode_job.rb` — Deleted (CLN-001)
- `spec/jobs/auto_process_episode_job_spec.rb` — Deleted (CLN-001)
- `spec/jobs/auto_process_episode_job_state_tracking_spec.rb` — Deleted (CLN-001)
- `lib/tasks/backfill_processing.rake` — Deleted (depended on AutoProcessEpisodeJob)

### Test Results
- **This milestone tests:** 4 passing, 1 failing (spec gap — see below)
- **Prior milestone tests:** 33 passing, all passing
- **Pre-existing specs:** 12 passing after updates

### Acceptance Criteria
- [x] TRX-001: `FetchPodcastFeedJob` does NOT enqueue `AutoProcessEpisodeJob` (call removed, class deleted)
- [x] TRX-002: `FetchPodcastFeedJob` still creates Episode records and UserEpisode inbox entries (verified by pre-existing specs)
- [x] TRX-003: `ProcessEpisodeJob` continues to work as-is (no changes made)
- [x] TRX-004: `DetectStuckProcessingJob` detects stuck UserEpisode records only (Episode block removed)
- [x] CLN-001: `AutoProcessEpisodeJob` class and both spec files deleted
- [x] CLN-002: Episode-level columns remain in schema (no migration)

### Spec Gaps
- **TRX-001 test (`fetch_podcast_feed_job_no_auto_process_spec.rb:27`):** References `AutoProcessEpisodeJob` constant in `not_to have_enqueued_job(AutoProcessEpisodeJob)`, but the class was deleted per CLN-001. Raises `NameError: uninitialized constant AutoProcessEpisodeJob`. The criterion is satisfied in code (the `perform_later` call and the class are both gone), but the test can't assert against a deleted constant.

### Notes
- Also deleted `lib/tasks/backfill_processing.rake` — a one-time onboarding backfill task that called `AutoProcessEpisodeJob.perform_later`. Not mentioned in the gameplan but would be broken after class deletion.
- Pipeline insight: Stage 4 test for TRX-001 should verify "no jobs enqueued" generically rather than referencing a specific class constant that the milestone deletes.

---

## M3: QA Test Data

**Status:** Complete
**Date:** 2026-02-17
**Commit:** `f282dcc`

### Files Created
- `lib/tasks/pipeline/library_scoped_processing_qa.rake` — Idempotent seed task creating test user, 2 podcasts, 9 episodes in 6 states

### Files Modified
- None

### Test Results
- **This milestone tests:** N/A (M3 is manual QA seed — no automated tests)
- **Prior milestone tests:** 37 passing, no regressions

### Acceptance Criteria
- [x] Seed task exists at `lib/tasks/pipeline/library_scoped_processing_qa.rake`
- [x] Task creates a test user with `digest_enabled: true` and `digest_sent_at: 25.hours.ago`
- [x] Task seeds episodes in various states: inbox, library+ready, library+pending, library+error, archived
- [x] Task seeds episode with `updated_at` older than 24 hours (tests 24-hour cap)
- [x] Task seeds episode with `updated_at` within 24 hours and `processing_status: ready`
- [x] Task is idempotent (uses `find_or_create_by` / `find_or_initialize_by` patterns)
- [x] Task prints summary with user email, podcast names, episode counts by state

### Spec Gaps
None (M3 has no automated tests by design)

### Notes
- Dev database not migrated in this environment, so the task couldn't be executed end-to-end. Verified via `rake -T` (task loads) and `ruby -c` (syntax OK).
- Task follows the same idempotency pattern as `qa_seed.rake` (`find_or_create_by` + `find_or_initialize_by`).
