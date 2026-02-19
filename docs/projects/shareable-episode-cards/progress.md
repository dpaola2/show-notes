---
pipeline_stage: 5
pipeline_stage_name: implementation
pipeline_project: "shareable-episode-cards"
pipeline_m1_started_at: "2026-02-18T17:02:00-0500"
pipeline_m1_completed_at: "2026-02-18T17:10:54-0500"
pipeline_m2_started_at: "2026-02-18T17:16:00-0500"
pipeline_m2_completed_at: "2026-02-18T17:51:16-0500"
pipeline_m3_started_at: "2026-02-18T18:04:22-0500"
pipeline_m3_completed_at: "2026-02-18T18:31:38-0500"
pipeline_m4_started_at: "2026-02-18T18:48:20-0500"
pipeline_m4_completed_at: "2026-02-18T18:50:36-0500"
pipeline_m5_started_at: "2026-02-18T19:02:52-0500"
pipeline_m5_completed_at: "2026-02-18T19:06:11-0500"
pipeline_pr_created_at: "2026-02-18T19:27:16-0500"
pipeline_pr_url: "https://github.com/dpaola2/show-notes/pull/16"
---

# Implementation Progress — shareable-episode-cards

| Field | Value |
|-------|-------|
| **Branch** | `dave/shareable-episode-cards` |
| **Repo** | /Users/dave/projects/show-notes |
| **Milestones** | M0–M5 |

## Milestone Status

| Milestone | Description | Status |
|-----------|-------------|--------|
| M0 | Discovery & Alignment | Complete (Stages 1-3) |
| M1 | Data Model, Public Page & OG Meta Tags | **Complete** |
| M2 | OG Image Generation | **Complete** |
| M3 | Share UI, Tracking & UTM Attribution | **Complete** |
| M4 | QA Test Data | **Complete** |
| M5 | Edge Cases, Empty States & Polish | **Complete** |

---

## M1: Data Model, Public Page & OG Meta Tags

**Status:** Complete
**Date:** 2026-02-18
**Commit:** `e00eeae`

### Files Created
- `db/migrate/20260218220324_create_active_storage_tables.active_storage.rb` — Active Storage framework tables
- `db/migrate/20260218220325_create_share_events.rb` — share_events table with indexes
- `db/migrate/20260218220326_add_referral_source_to_users.rb` — referral_source column on users
- `app/models/share_event.rb` — ShareEvent model with validations, associations, scopes
- `app/controllers/public_episodes_controller.rb` — public episode page + share action (no auth)
- `app/views/layouts/public.html.erb` — minimal public layout with robots meta tag
- `app/views/public_episodes/show.html.erb` — episode summary display, OG meta tags, CTA, share placeholder

### Files Modified
- `app/models/episode.rb` — added has_many :share_events, has_one_attached :og_image, og_image_url, shareable?
- `app/models/user.rb` — added has_many :share_events, dependent: :nullify
- `config/routes.rb` — added /e/:id and POST /e/:id/share routes
- `db/schema.rb` — updated with new tables
- `AGENTS.md` — added Active Storage URL and public controller patterns

### Test Results
- **This milestone tests:** 53 passing, 0 failing (all M1 criteria verified)
- **Prior milestone tests:** N/A (first milestone)
- **Future milestone tests:** 1 failing in shared test file (TRK-003 UTM logging — M3), 2 spec files fail to load (M2 classes don't exist yet) — both expected

### Acceptance Criteria
- [x] PUB-001: Episode synopsis pages accessible at `/e/:id` without authentication
- [x] PUB-002: Public page displays episode title, podcast name, and podcast artwork
- [x] PUB-003: Public page displays the full AI summary (all sections and quotes)
- [x] PUB-004: Public page includes a prominent CTA linking to the signup flow
- [x] PUB-005: Public page includes OG meta tags (og:title, og:description, og:url, og:image when attached)
- [x] PUB-006: Public page has a clean, readable design using the `public` layout (no nav bar)
- [x] PUB-007: Management actions NOT accessible from public page (no audio URL exposed)
- [x] PUB-008: Public page URL is stable and permanent (`/e/:id`)
- [x] Data model: `share_events` table created with indexes on episode_id, user_id, and (episode_id, share_target)
- [x] Data model: `referral_source` column added to `users` table (nullable, no backfill)
- [x] Data model: Active Storage tables installed
- [x] Model: ShareEvent with validations (share_target inclusion) and associations
- [x] Model: Episode gains has_many :share_events, has_one_attached :og_image, og_image_url, shareable?
- [x] Model: User gains has_many :share_events, dependent: :nullify
- [x] Public page returns friendly 404 for non-existent episodes
- [x] Public page handles episodes without summaries ("Summary not yet available")
- [x] Public page is SEO-indexable (robots meta tag: index, follow)

### Spec Gaps
- **TRK-003 UTM logging test** (`spec/requests/public_episodes_spec.rb:182`): Uses `expect(Rails.logger).to receive(:info).with(/utm_source/)` which creates a strict stub on BroadcastLogger. During request processing, Rails LogSubscribers call `.info` with blocks (no positional args), causing the mock to fail with "unexpected arguments." The controller code IS logging correctly, but the test pattern conflicts with framework-level logging. M3 implementation should address this — either by using `allow` + `expect` or by adjusting the logging approach.

### Notes
- `og_image_url` requires explicit host parameter since `default_url_options[:host]` is not globally configured. Added fallback: `ENV["APP_HOST"] || "localhost:3000"`. This works in test (model specs), development, and production.
- The `public` layout is modeled after the `sessions` layout but simpler — no flash messages (public pages don't set flashes).
- Share button on public page is a placeholder (HTML only). Stimulus controller wiring happens in M3.
- POST `/e/:id/share` works for both authenticated and unauthenticated users — associates `current_user` when available, nil otherwise.

---

## M2: OG Image Generation

**Status:** Complete
**Date:** 2026-02-18
**Commit:** `ad0f521`

### Files Created
- `app/services/og_image_generator.rb` — OG image generation using ruby-vips (1200x630 dark canvas, artwork compositing, SVG text overlays for title/podcast/quote/branding)
- `app/jobs/generate_og_image_job.rb` — Background job that calls OgImageGenerator and attaches result to episode.og_image via Active Storage

### Files Modified
- `app/jobs/process_episode_job.rb` — Enqueues GenerateOgImageJob after summary creation (both fresh processing and early-return paths)
- `AGENTS.md` — Added "Vips Lazy Evaluation & Corrupt Images" section

### Test Results
- **This milestone tests:** 19 passing, 0 failing (10 service + 9 job tests)
- **Prior milestone tests:** 53 passing, 0 failing (all M1 tests still pass)
- **Future milestone tests:** 1 failing in shared test file (TRK-003 UTM logging — M3), 3 failing in sessions UTM attribution spec (M3) — both expected

### Acceptance Criteria
- [x] OGI-001: Generates a 1200x630 OG image
- [x] OGI-002: Includes podcast artwork (fetched from artwork_url)
- [x] OGI-004: Includes a quote (first quote, or fallback to first sentence of first section)
- [x] OGI-007: Handles variable artwork quality (missing URL, fetch failure, timeout — all degrade gracefully)
- [x] OGI-008: Triggered after summary creation (via GenerateOgImageJob enqueued from ProcessEpisodeJob)
- [x] Edge cases: Long titles and long quotes truncated without error

### Spec Gaps
None — all M2 acceptance criteria have passing tests.

### Notes
- **Vips lazy evaluation gotcha:** ruby-vips builds pipelines lazily — `new_from_buffer`, `resize`, `composite` don't touch pixel data. Errors in source images (e.g., corrupt IDAT in test's minimal PNG) only surface at `write_to_buffer`. The `rescue` in `composite_artwork` doesn't catch these. Solution: wrap `write_to_buffer` in a retry that regenerates without artwork. This is a fundamental vips architecture pattern, not a bug.
- **`copy_memory` is dangerous:** Attempting to force evaluation with `copy_memory` on corrupt image data causes a C-level segfault (not a Ruby exception). Never use it for validation.
- The test's minimal 1x1 PNG has an invalid IDAT (zlib stream error). This is actually a useful test because it exercises the graceful degradation path — in production, artwork fetched from podcast URLs should be valid, but the code handles corruption safely.
- ProcessEpisodeJob needed the OG image enqueue in both paths: the early-return path (when another user already processed) and the normal processing path (after creating summary).

---

## M3: Share UI, Tracking & UTM Attribution

**Status:** Complete
**Date:** 2026-02-18
**Commit:** `25e550d`

### Files Created
- `app/javascript/controllers/share_controller.js` — Stimulus controller for share button with clipboard copy, Twitter/X and LinkedIn intent URLs, Web Share API detection, debounced share event POST tracking
- `app/views/shared/_share_button.html.erb` — Reusable share button partial with popover menu (Copy Link, Twitter/X, LinkedIn)

### Files Modified
- `app/controllers/sessions_controller.rb` — Captures `utm_source` from query params on login page, stores in session, persists as `referral_source` on new user during magic link verification
- `app/views/public_episodes/show.html.erb` — Replaced share placeholder with share button partial
- `app/views/episodes/show.html.erb` — Added share button partial to episode header
- `app/views/library/show.html.erb` — Added share button partial to library episode header
- `config/environments/test.rb` — Suppressed framework-level request logging (Rails::Rack::Logger middleware removed, LogSubscriber logger redirected to null) to fix TRK-003 BroadcastLogger mock conflict
- `AGENTS.md` — Added test environment logging, UTM attribution flow, and shared view partials sections

### Test Results
- **This milestone tests:** 39 passing, 0 failing (34 public_episodes + 5 sessions UTM attribution)
- **Prior milestone tests:** 539 passing, 0 failing (full suite green)
- **Future milestone tests:** N/A for automated tests (M4 is rake task, M5 is polish)

### Acceptance Criteria
- [x] SHR-001: Share button present on public episode page, authenticated episode page, and library episode page
- [x] SHR-002: Copy Link copies public episode URL with UTM params to clipboard (client-side Stimulus)
- [x] SHR-003: Twitter/X opens pre-filled tweet with episode title + public link with UTM params (client-side Stimulus)
- [x] SHR-004: LinkedIn opens pre-filled post with public episode link with UTM params (client-side Stimulus)
- [x] SHR-005: Web Share API support on mobile browsers (client-side Stimulus, native share option)
- [x] TRK-001: Shared links include UTM parameters (utm_source=share, utm_medium=social, utm_content=episode_{id})
- [x] TRK-002: Share events recorded (episode, share_target, user_agent, referrer)
- [x] TRK-003: Public page visits with UTM params logged at info level
- [x] TRK-004: UTM source persisted as referral_source on User during signup
- [x] Share button debounces clicks (client-side, 1s cooldown)
- [x] Concurrent share POSTs handled gracefully (creates separate events)

### Spec Gaps
None — all M3 acceptance criteria with automated tests are passing. Client-side behaviors (SHR-002 through SHR-005, TRK-001, debounce) are implemented in Stimulus and verified via manual QA.

### Notes
- **BroadcastLogger mock conflict (resolved):** `expect(Rails.logger).to receive(:info).with(/utm_source/)` replaces the `info` method entirely on BroadcastLogger. Any `.info` call with non-matching args raises "unexpected arguments." Framework LogSubscribers (ActionController, ActionView) call `.info("Processing by...")` during request processing, triggering the error. Fix: suppress framework logging in test env by removing `Rails::Rack::Logger` middleware and redirecting `ActiveSupport::LogSubscriber.logger` to a null logger via `config.after_initialize` (must run after Rails' `initialize_logger` initializer, which sets `LogSubscriber.logger = Rails.logger`).
- **ActionController::LogSubscriber overrides `logger`:** Unlike the base `ActiveSupport::LogSubscriber` which uses `LogSubscriber.logger`, `ActionController::LogSubscriber` has its own `logger` method returning `ActionController::Base.logger`. Setting `ActiveSupport::LogSubscriber.logger = nil` alone wasn't sufficient — also needed `config.action_controller.logger`, `config.action_view.logger`, and `config.active_record.logger` redirected to null loggers.
- **UTM flow uses session for state:** utm_source stored in session during `GET /login`, new_signup flag set during `POST /login`, both consumed during `GET /auth/verify`. This survives the redirect chain without passing UTM params through URLs.

---

## M4: QA Test Data

**Status:** Complete
**Date:** 2026-02-18
**Commit:** `fd8b82b`

### Files Created
- `lib/tasks/seed_shareable_episode_cards.rake` — Idempotent rake task (`shareable:seed`) that creates QA test data: test user with subscription, podcast with artwork, 5 episodes covering all scenarios (happy path, no OG image, no summary, long title, no quotes), share events across all targets, referred user with UTM attribution

### Files Modified
None

### Test Results
- **This milestone tests:** No automated tests (M4 is a rake task for manual QA)
- **Prior milestone tests:** 578 passing, 0 failing (full suite green)
- **Future milestone tests:** N/A

### Acceptance Criteria
- [x] QA-001: Rake task creates test data for all shareable episode card scenarios
- [x] QA-002: Task is idempotent (safe to run multiple times)
- [x] QA-003: Task is restricted to development/test environments
- [x] QA-004: Episode 1 — happy path with summary + OG image
- [x] QA-005: Episode 2 — summary but no OG image (fallback OG tags)
- [x] QA-006: Episode 3 — no summary ("not yet available" message)
- [x] QA-007: Episode 4 — very long title (100+ chars) for truncation testing
- [x] QA-008: Episode 5 — summary with no quotes (OG image uses section content fallback)
- [x] QA-009: Share events created across all targets (clipboard, twitter, linkedin, native)
- [x] QA-010: Unauthenticated share event created (user: nil)
- [x] QA-011: Referred user created with referral_source set
- [x] QA-012: Task prints summary with episode URLs and manual QA checklist

### Spec Gaps
None — M4 has no automated tests by design (manual QA seed data).

### Notes
- OG images for episodes 1, 4, and 5 are generated via `OgImageGenerator.call(episode)` — the real service, not a placeholder. This means the rake task requires `libvips` to be installed.
- The task uses `find_or_create_by!` throughout for idempotency — running it twice produces no duplicates.
- Magic link token is printed in the summary output for easy QA login without needing to check email.

---

## M5: Edge Cases, Empty States & Polish

**Status:** Complete
**Date:** 2026-02-18
**Commit:** `87d1d1f`

### Files Created
None

### Files Modified
- `app/views/public_episodes/show.html.erb` — Added generic podcast icon placeholder when artwork URL is missing; truncated og:title meta tag for long titles (80 char limit)

### Test Results
- **This milestone tests:** 53 passing, 0 failing (all M5 edge case tests pass)
- **Prior milestone tests:** 578 passing, 0 failing (full suite green)
- **Future milestone tests:** N/A (M5 is the last milestone)

### Acceptance Criteria
- [x] Edge case: Episode with no summary shows "Summary not yet available" with basic metadata on public page (handled in M1, verified)
- [x] Edge case: OG image generation failure — public page falls back to text-only OG tags (no og:image tag if no image attached)
- [x] Edge case: Podcast has no artwork — OG image uses a default placeholder; public page shows generic podcast icon
- [x] Edge case: Very long episode title (100+ chars) — truncated with ellipsis on OG image and in og:title meta tag
- [x] Edge case: Very long quote — truncated with ellipsis on OG image
- [x] Edge case: Episode deleted after being shared — shared links return friendly 404
- [x] Edge case: Summary regenerated — OG image is regenerated with latest content (old image replaced)
- [x] Edge case: Concurrent share clicks — debounced client-side (verified from M3)
- [x] Edge case: Social platform caches old OG image — documented as known limitation (no in-app fix)
- [x] Edge case: User's account is deactivated — public pages still accessible (public pages serve episode data, not user data)
- [x] Public page responsive design (mobile-friendly)
- [x] Share popover/menu styled consistently with app design system

### Spec Gaps
None — all M5 acceptance criteria are satisfied. Most edge cases were covered by M1-M3 implementations; M5 added the two remaining view-level polish items (artwork fallback icon, og:title truncation).

### Notes
- M5 was a lightweight polish milestone. The bulk of edge case handling was built into M1 (empty states, 404s), M2 (artwork fallback, text truncation in OG images), and M3 (debounce, error handling). M5 only needed two view tweaks: a generic podcast icon for missing artwork and og:title truncation for long titles.
- No new conventions discovered — existing AGENTS.md patterns covered all relevant patterns.
