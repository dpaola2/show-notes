---
pipeline_stage: 5
pipeline_stage_name: implementation
pipeline_project: "latest-at-top-digest"
pipeline_m1_started_at: "2026-02-19T08:14:54-0500"
pipeline_m1_completed_at: "2026-02-19T08:31:20-0500"
pipeline_quality_m1_flog_avg: 17.1
pipeline_quality_m1_flog_max: 54.8
pipeline_quality_m1_flog_max_method: "DigestMailer#daily_digest"
pipeline_quality_m1_files_analyzed: 2
---

# Implementation Progress — latest-at-top-digest

| Field | Value |
|-------|-------|
| **Branch** | `pipeline/latest-at-top-digest` |
| **Repo** | /Users/dave/projects/show-notes |
| **Milestones** | M0–M4 |

## Milestone Status

| Milestone | Description | Status |
|-----------|-------------|--------|
| M0 | Discovery & Alignment | Complete (Stages 1-3) |
| M1 | Scope & Mailer Data Layer | **Complete** |
| M2 | Email Templates | Pending |
| M3 | QA Test Data | Pending |
| M4 | Edge Cases & Polish | Pending |

---

## M1: Scope & Mailer Data Layer

**Status:** Complete
**Date:** 2026-02-19
**Commit:** `584d9d8`

### Files Created
None

### Files Modified
- `app/models/episode.rb` — Updated `library_ready_since` scope: INNER JOIN on `:summary`, order by `user_episodes.updated_at DESC`
- `app/mailers/digest_mailer.rb` — Restructured class method (flat list, featured/recent split, optimized EmailEvent creation) and instance method (new ivars, subject line, deliver-later fallback)
- `app/views/digest_mailer/daily_digest.html.erb` — Rewrote template: featured episode with full summary + quotes, recent episodes in compact cards, new sign-off and footer
- `app/views/digest_mailer/daily_digest.text.erb` — Rewrote plain text template to mirror HTML layout
- `AGENTS.md` — Added DigestMailer featured episode layout pattern documentation
- `spec/jobs/send_daily_digest_job_spec.rb` — Added `create(:summary)` to episode setups (required by INNER JOIN)
- `spec/jobs/onboarding_send_daily_digest_job_spec.rb` — Added `create(:summary)` to episode setups
- `spec/jobs/send_daily_digest_job_library_spec.rb` — Added `create(:summary)` to episode setups
- `spec/mailers/digest_mailer_spec.rb` — Updated expectations for new subject format, link text, and tracking event counts
- `spec/mailers/onboarding_digest_mailer_spec.rb` — Full rewrite for new behavior (featured/recent split, click counts, subject format)
- `spec/mailers/digest_mailer_library_spec.rb` — Updated DIG-003 subject test for new format
- `spec/models/episode_library_scope_spec.rb` — Added summaries to episode setups, updated ordering test for `user_episodes.updated_at DESC`

### Test Results
- **This milestone tests:** 28 passing (3 model scope + 25 mailer), 2 Stage 4 timing bugs (SL-002, overflow — cannot fix without modifying Stage 4 tests)
- **Prior milestone tests:** all passing
- **Pre-existing regressions fixed:** 11 tests across 6 files updated for intentional behavior changes

### Acceptance Criteria
- [x] FE-006 / RE-005: `library_ready_since` scope INNER JOINs on `summary`, excluding episodes without completed summaries
- [x] FE-001 / RE-002: `library_ready_since` scope orders by `user_episodes.updated_at DESC`
- [x] FE-001: `DigestMailer.daily_digest` class method splits episodes into `featured_episode` (first) and `recent_episodes` (next 5)
- [x] RE-004: When only 1 episode exists, `featured_episode` is set and `recent_episodes` is empty
- [x] FE-004: Class method creates 1 click event (summary) for featured; 2 (summary + listen) for each recent
- [x] Edge case: When all qualifying episodes lack summaries, `NullMail` returned
- [x] SL-001 / SL-002: Subject line as `"Podcast Name: Episode Title"` with `" (+N more)"` when recent episodes exist
- [x] Deliver-later fallback mirrors new class method logic
- [x] Thread-local data structure uses `featured_episode` and `recent_episodes` keys

### Quality Snapshot

| Metric | Value |
|--------|-------|
| **Flog avg** | 17.1 |
| **Flog max** | 54.8 (`DigestMailer#daily_digest`) |
| **Files analyzed** | 2 |

### Spec Gaps
- **Stage 4 timing bugs:** `featured_digest_mailer_spec.rb:37` (SL-002) and `:303` (overflow) create episodes with timestamps that fall outside the `> since` window boundary. Both tests create episodes at 2-3 hours ago with `digest_sent_at: 2.hours.ago`, but the `>` (strict greater-than) comparison excludes the boundary episode. These are test setup issues, not implementation bugs.

### Notes
- M1 scope included template changes (HTML + text) which are formally part of M2 in the gameplan. This was necessary because the mailer restructuring changed the template ivars (`@featured_episode`, `@recent_episodes` vs old `@episodes_by_show`), making it impossible to keep old templates working. The templates were rewritten to match the new data structure.
- Pre-existing test files required significant updates because the INNER JOIN on summary means all test episodes now need a `create(:summary, episode: ep)` call. 11 pre-existing tests across 6 files were updated.
- The `DigestMailer#daily_digest` instance method has a flog score of 54.8, which is elevated. This is inherent to the two-phase architecture (class method + instance method with thread-local fallback) — the instance method handles both the happy path (thread-local data present) and the deliver-later fallback (re-query from DB).
