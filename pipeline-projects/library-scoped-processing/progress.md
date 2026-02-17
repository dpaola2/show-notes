---
pipeline_stage: 5
pipeline_stage_name: implementation
pipeline_project: "library-scoped-processing"
pipeline_m1_started_at: "2026-02-17T09:58:46-0500"
pipeline_m1_completed_at: "2026-02-17T10:03:51-0500"
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
| M2 | Remove Auto-Processing from Feed Fetch | Pending |
| M3 | QA Test Data | Pending |
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
