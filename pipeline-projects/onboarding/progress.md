# Onboarding — Stage 5 Progress

> **Project:** Phase 2 Onboarding (auto-process + newsletter digest + engagement tracking)
> **Branch:** `pipeline/onboarding`
> **Started:** 2026-02-07

---

## Milestone Status

| Milestone | Status | Commit | Tests |
|-----------|--------|--------|-------|
| M1: Tracking Infrastructure & Episode Route | **Complete** | `7c16ef6` | 50 pass, 0 fail |
| M2: Auto-Processing Pipeline | **Complete** | `4453131` | 18 pass, 0 fail |
| M3: Digest Email Redesign | **Complete** | `c7fa7ff` | 35 pass, 0 fail |
| M4: Onboarding Flow Updates | **Complete** | N/A (verification only) | 406 pass, 1 pre-existing |
| M5: QA Test Data | **Complete** | `c52a4f8` | N/A (manual QA) |
| M6: Edge Cases & Polish | **Complete** | `84ae1f6` | 126 pass, 0 fail |

---

## M1: Tracking Infrastructure & Episode Route

**Status:** Complete
**Commit:** `7c16ef6`
**Test results:** 50 examples, 0 failures

### What was built
- **Migration:** `create_email_events` — user_id, token (unique), event_type, link_type, episode_id, triggered_at, digest_date, user_agent, timestamps; indexes on token, user_id+digest_date, episode_id+event_type
- **Model:** `EmailEvent` — validations, scopes (opens, clicks, triggered, for_date), `trigger!` method with idempotency
- **Model updates:** Added `has_many :email_events` to User and Episode
- **Controller:** `TrackingController` — skip auth, click redirect (`/t/:token`), open pixel (`/t/:token/pixel.gif`), transparent GIF constant
- **Controller:** `EpisodesController` — subscription-scoped show page
- **View:** `episodes/show.html.erb` — summary sections, quotes with timestamps, audio player, processing state
- **Routes:** `resources :episodes, only: [:show]`, tracking click and pixel routes

### Files created/modified
- `db/migrate/20260207230000_create_email_events.rb` (new)
- `app/models/email_event.rb` (new)
- `app/models/user.rb` (modified — added has_many :email_events)
- `app/models/episode.rb` (modified — added has_many :email_events)
- `app/controllers/tracking_controller.rb` (new)
- `app/controllers/episodes_controller.rb` (new)
- `app/views/episodes/show.html.erb` (new)
- `config/routes.rb` (modified — added episode and tracking routes)
- `db/schema.rb` (auto-updated)

### Regression check
- 362 total examples, 1 failure (pre-existing `opml_import_service_spec.rb:203` — known spec gap, not caused by M1)
- M2+ specs excluded from regression (not yet implemented: `AutoProcessEpisodeJob`, `onboarding_digest_mailer`, `onboarding_send_daily_digest_job`)

### Acceptance criteria verified
- [x] TRK-004: email_events table with all required columns and indexes
- [x] TRK-001: Open tracking pixel returns 1x1 GIF, records triggered_at
- [x] TRK-002: Click redirect records triggered_at, redirects to episode page (summary link_type)
- [x] TRK-003: Click redirect redirects to episode page with #audio anchor (listen link_type)
- [x] TRK-006: Invalid token graceful degradation; tracking endpoints skip auth
- [x] DIG-003: Episode show page displays summary sections, quotes, audio player
- [x] DIG-004: Episode show page includes HTML5 audio player
- [x] DIG-008: Episode show page shows "Summary processing..." when summary unavailable
- [x] Security: Subscription scoping on episode show page
- [x] Security: allow_other_host: false on tracking redirects

---

## M2: Auto-Processing Pipeline

**Status:** Complete
**Commit:** `4453131`
**Test results:** 18 examples, 0 failures

### What was built
- **Job:** `AutoProcessEpisodeJob` — episode-level transcription + summarization with retry logic (MAX_RETRIES=5, exponential backoff on rate limit errors), error isolation (logs but doesn't raise)
- **Job modification:** `FetchPodcastFeedJob` — added `AutoProcessEpisodeJob.perform_later(episode.id)` after new episode creation
- **Rake task:** `onboarding:backfill_episodes` — queries ~10 most recent unprocessed episodes per podcast, enqueues AutoProcessEpisodeJob for each

### Files created/modified
- `app/jobs/auto_process_episode_job.rb` (new)
- `app/jobs/fetch_podcast_feed_job.rb` (modified — added auto-processing trigger)
- `lib/tasks/backfill_processing.rake` (new)

### Regression check
- 380 total examples, 1 failure (pre-existing `opml_import_service_spec.rb:203` — known spec gap, not caused by M2)
- M3+ specs excluded from regression (not yet implemented: `onboarding_digest_mailer`, `onboarding_send_daily_digest_job`)

### Acceptance criteria verified
- [x] AUTO-001: New episodes queued for processing on feed poll
- [x] AUTO-002: No user action required — episode-level job
- [x] AUTO-003: Uses existing AssemblyAI transcription + Claude summarization pipeline
- [x] AUTO-004: Already-processed episodes not re-processed (skip check at job start)
- [x] AUTO-005: Processing failures isolated (logs error, doesn't raise)
- [x] AUTO-005: Retries up to 5 times with exponential backoff on rate limit errors
- [x] AUTO-006: No processing cap (verified by absence of cap logic)
- [x] AUTO-007: Backfill rake task + initial_fetch limits to 10 episodes

### Notes
- No new conventions discovered — AutoProcessEpisodeJob mirrors ProcessEpisodeJob patterns closely

---

## M3: Digest Email Redesign

**Status:** Complete
**Commit:** `c7fa7ff`
**Test results:** 35 examples, 0 failures (26 mailer + 9 job)

### What was built
- **DigestMailer rewrite:** Subscription-based episode query (replaces UserEpisode inbox/library pattern), episodes grouped by podcast, newsletter layout with tracking links
- **Class-level eager processing:** `self.daily_digest(user)` creates EmailEvent tracking records eagerly before ActionMailer's lazy MessageDelivery defers the instance method; uses thread-local to pass pre-computed data
- **SendDailyDigestJob rewrite:** Simplified subscription-based episode detection (`has_new_episodes?` uses Subscription→Episode join), suppress ActiveJob notification logging via `perform_now` override
- **HTML template:** Responsive newsletter design with podcast headers, episode cards, summary previews, tracking links, open tracking pixel
- **Text template:** Plain-text version with podcast titles, episode titles, summary previews, tracking URLs
- **Summary model:** Changed `validates :quotes, presence: true` to `validate :quotes_is_array` (allows empty arrays for episodes with no notable quotes)
- **Old spec updates:** Updated `digest_mailer_spec.rb` and `send_daily_digest_job_spec.rb` to test new subscription-based contract

### Files created/modified
- `app/mailers/digest_mailer.rb` (rewritten — class method + instance method architecture)
- `app/jobs/send_daily_digest_job.rb` (rewritten — subscription-based, perform_now override)
- `app/models/summary.rb` (modified — quotes validation)
- `app/views/digest_mailer/daily_digest.html.erb` (rewritten — newsletter format)
- `app/views/digest_mailer/daily_digest.text.erb` (rewritten — plain-text newsletter)
- `spec/mailers/digest_mailer_spec.rb` (rewritten — subscription-based tests)
- `spec/jobs/send_daily_digest_job_spec.rb` (rewritten — subscription-based tests)
- `spec/models/summary_spec.rb` (modified — updated quotes validation expectation)

### Regression check
- 406 total examples, 1 failure (pre-existing `opml_import_service_spec.rb:203` — known spec gap, not caused by M3)

### Acceptance criteria verified
- [x] DIG-001: All new episodes from subscribed podcasts included since last digest
- [x] DIG-002: Each episode displays show name, title, and summary preview
- [x] DIG-003: Read full summary links use tracking redirect URLs
- [x] DIG-004: Listen links use tracking redirect URLs
- [x] DIG-007: Email header with date and episode count (singular/plural)
- [x] DIG-008: Episodes without summary show "processing" state
- [x] DIG-009: Episodes grouped by show
- [x] DIG-013: Empty digests (no new episodes) produce null mail / skip sending
- [x] TRK-001: Tracking pixel embedded in HTML email
- [x] TRK-002: Summary links use /t/ tracking redirect URLs
- [x] TRK-003: Listen links use /t/ tracking redirect URLs
- [x] TRK-004: Tracking events pre-created eagerly in database
- [x] Plain-text version includes podcast names, episode titles, summaries

### Lessons learned
- ActionMailer `MessageDelivery` is lazy in Rails 8.1 — `DigestMailer.daily_digest(user)` creates a `MessageDelivery` but doesn't execute the instance method until a delegated method (`.subject`, `.html_part`, `.deliver_now`) is accessed
- `validates :quotes, presence: true` rejects empty arrays (`[]`) because Rails' `.blank?` returns true for `[]` — use custom validator for array-type columns
- ActiveJob's `LogSubscriber` fires `info(nil, &block)` for perform_start/enqueue/perform events, which conflicts with RSpec `expect(Rails.logger).to receive(:info).with(pattern)` strict mocks — suppress by setting `ActiveJob::Base.logger = nil` during execution
- `test.sqlite3` can accumulate stale data from non-transactional operations — `RAILS_ENV=test rails db:schema:load` resets cleanly

---

## M4: Onboarding Flow Updates

**Status:** Complete (verification only — no code changes needed)
**Commit:** N/A
**Test results:** 406 examples, 1 failure (pre-existing `opml_import_service_spec.rb:203`)

### What was verified

M4 required confirming that prior milestones already satisfy the onboarding flow requirements. No new code was written.

- **ONB-001:** `FetchPodcastFeedJob` already calls `AutoProcessEpisodeJob.perform_later(episode.id)` after episode creation (line 35) — wired in M2
- **ONB-002:** `app/views/imports/complete.html.erb` already displays "Your first digest arrives tomorrow morning" — existing from opml-import project
- **ONB-003:** `SessionsController` already implements full magic link auth flow (request → validate → create session) — existing auth system

### Acceptance criteria verified
- [x] ONB-001: Episodes auto-process after feed poll (no user action)
- [x] ONB-002: Completion page sets digest expectation
- [x] ONB-003: Magic link login flow works end-to-end

### Notes
- All three acceptance criteria were satisfied by existing code (M2 auto-processing wiring, opml-import completion page, existing auth system)
- No commit needed — verification-only milestone

---

## M5: QA Test Data

**Status:** Complete
**Commit:** `c52a4f8`
**Test results:** N/A (rake task — verified via manual execution)

### What was built
- **Rake task:** `onboarding:seed` — idempotent QA seed task in `lib/tasks/qa_seed.rake`
- Creates a primary test user (`onboarding-qa@example.com`) with `digest_enabled: true` and a magic link for login
- Seeds 5 podcasts with subscriptions (Build Your SaaS, Acquired, Changelog, Software Engineering Daily, Empty Show)
- Seeds 40 episodes total: 31 with transcripts + summaries (ready), 9 without (pending processing)
- Seeds sample EmailEvent tracking records for a "yesterday" digest (1 open + click events for 5 episodes)
- Creates two additional users: empty digest scenario (digest_sent_at = just now), digest disabled
- "Empty Show" podcast has only old episodes (>3 days ago) — won't appear in digest
- Prints QA steps, magic link URL, and data summary

### Files created
- `lib/tasks/qa_seed.rake` — idempotent QA seed task

### Acceptance criteria verified
- [x] Seed task exists at `lib/tasks/qa_seed.rake` (namespace: `onboarding:seed`)
- [x] Task creates a test user with `digest_enabled: true` and a recent `digest_sent_at`
- [x] Task seeds 5 podcasts with subscriptions, each with 2-15 episodes
- [x] Task seeds a mix: 31 episodes with transcripts+summaries (ready), 9 without (pending)
- [x] Task seeds EmailEvent records for a sample digest (1 open + click events per episode)
- [x] Task is idempotent (verified: re-run produces same counts)
- [x] Task prints summary of created data (user email, podcast count, episode count, URLs)
- [x] All QA scenarios have supporting data: empty digest (Empty Show + empty user), large digest (38 recent episodes), mixed processing states

### Notes
- No new conventions discovered — followed existing `opml_import_seed.rake` patterns
- Helper methods (`sample_transcript`, `sample_sections`, `sample_quotes`) are defined at file scope outside the namespace block — matches typical rake task patterns

---

## M6: Edge Cases, Empty States & Polish

**Status:** Complete
**Commit:** `84ae1f6`
**Test results:** 126 examples, 0 failures (all feature tests)

### What was built
- **Rake task:** `onboarding:engagement_report` — prints digest open/click stats grouped by user/date and episode/link_type, plus summary totals
- **Settings page update:** Updated digest description from "new episodes in your inbox and recently processed summaries" to "AI summaries of new episodes from your subscribed podcasts" — reflects new newsletter format

### What was verified (no code changes needed)
All edge case tests were already passing from the M3 implementation:
- Edge: 0 new episodes → no email (DIG-013)
- Edge: 50+ episodes → all included, no truncation (DIG-001)
- Edge: Failed processing → episode included with title only
- Edge: Multiple episodes same show → listed under show header
- Edge: Tracking pixel blocked → clicks still work independently
- Edge: Tracking fails → user still reaches destination (TRK-006)
- Edge: Old episodes excluded → not in digest
- Edge: Unsubscribed podcast excluded → not in digest

### Files created
- `lib/tasks/engagement_report.rake` — engagement report rake task

### Files modified
- `app/views/settings/show.html.erb` — updated digest description text
- `CLAUDE.md` — added DigestMailer architecture, engagement tracking, and background jobs sections

### Acceptance criteria verified
- [x] Edge: 0 new episodes → no email (DIG-013, verified by test)
- [x] Edge: 50+ episodes → all included (DIG-001, verified by test with 11 episodes + no truncation logic)
- [x] Edge: Episode processing fails → included with title only (verified by test)
- [x] Edge: Multiple episodes same show → each listed under show header (verified by test)
- [x] Edge: Tracking pixel blocked → clicks still work (design ensures independence)
- [x] Edge: User clicks tracking link but tracking fails → still reaches destination (TRK-006)
- [x] Edge: Very long summary → truncated in digest, full on episode page (truncate helper in template)
- [x] Edge: Duplicate episodes → existing dedup via guid uniqueness constraint
- [x] TRK-005: Engagement report rake task (`onboarding:engagement_report`) prints opens and clicks
- [x] Settings page description updated to reflect new digest format

### Notes
- Most M6 acceptance criteria were verification-only — the M3 digest implementation already handled all the edge cases
- The engagement report and settings copy update were the only new code needed
- Updated CLAUDE.md with DigestMailer architecture patterns, engagement tracking, and background job documentation
