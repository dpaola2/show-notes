---
pipeline_stage: 0
pipeline_stage_name: prd
pipeline_project: "library-scoped-processing"
pipeline_started_at: "2026-02-17T08:17:48-0500"
pipeline_completed_at: "2026-02-17T08:19:27-0500"
---

# Library-Scoped Processing — PRD

|  |  |
| -- | -- |
| **Product** | Show Notes |
| **Version** | 3 |
| **Author** | Stage 0 (Pipeline) |
| **Date** | 2026-02-17 |
| **Status** | Draft — Review Required |
| **Platforms** | Web only |
| **Level** | 1 |

---

## 1. Executive Summary

**What:** Revert email digests and transcription to only operate on episodes the user has explicitly added to their library, rather than all episodes from subscribed podcasts.

**Why:** Show Notes is a personal tool. The recent digest redesign (Feb 7) and auto-transcription on feed fetch were built for a multi-user/newsletter model that doesn't match how the app is actually used. The digest should surface curated content, not everything published. Auto-transcription burns AssemblyAI and Claude API credits on episodes that may never be read.

**Key Design Principles:**
- Library is the user's explicit curation signal — only process what's in the library
- Feed fetching and inbox discovery remain untouched — the inbox is still the funnel
- Simplify, don't add — this is a revert/removal, not new functionality

---

## 2. Goals & Success Metrics

### Goals
- Digest emails only contain episodes the user has moved to their library
- Transcription only runs when an episode enters the library (not on feed fetch)
- Reduce unnecessary API spend on episodes the user never reads

### Success Metrics

| Metric | Target | Timeframe |
|--------|--------|-----------|
| Digest contains only library episodes | 100% of digests | Immediate |
| Zero auto-transcription jobs on feed fetch | 0 `AutoProcessEpisodeJob` enqueues from `FetchPodcastFeedJob` | Immediate |
| API cost reduction | Transcription calls drop to only library-added episodes | 7 days |

---

## 3. Feature Requirements

### Digest Email

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| DIG-001 | Digest email queries `user_episodes` in library location instead of all episodes from subscribed podcasts | Web | Must |
| DIG-002 | Digest shows library episodes with `processing_status=ready` whose status became ready after `digest_sent_at`, capped to the last 24 hours (whichever is more recent). This prevents a backlog of old episodes appearing after a gap in digest delivery. | Web | Must |
| DIG-003 | Digest subject line and copy reflect library-centric framing (e.g., "Your library updates" not "Your podcasts this morning") | Web | Should |
| DIG-004 | Digest is not sent if no library episodes became ready within the eligibility window | Web | Must |

### Transcription Scope

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| TRX-001 | `FetchPodcastFeedJob` does NOT enqueue `AutoProcessEpisodeJob` when discovering new episodes | Web | Must |
| TRX-002 | `FetchPodcastFeedJob` still creates `Episode` records and `UserEpisode` inbox entries for subscribers | Web | Must |
| TRX-003 | `ProcessEpisodeJob` (triggered by `move_to_library!`) continues to work as-is | Web | Must |
| TRX-004 | `DetectStuckProcessingJob` detects stuck `UserEpisode` records only (Episode-level detection is removed since `AutoProcessEpisodeJob` is removed) and marks them as error for manual retry | Web | Must |

### Cleanup

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| CLN-001 | `AutoProcessEpisodeJob` class and its specs are deleted (single call site is being removed; dead code is confusing) | Web | Must |
| CLN-002 | Episode-level `processing_status`, `processing_error`, `last_error_at` columns remain — needed for backward compatibility with legacy auto-processed records (no migration to remove them) | Web | Must |

---

## 4. Platform-Specific Requirements

### Web (Rails)
- Digest mailer query changes from `Episode.joins(podcast: :subscriptions)` to a `user_episodes`-based query scoped to library location
- `FetchPodcastFeedJob` has its `AutoProcessEpisodeJob.perform_later` call removed
- No new migrations, routes, or controllers needed — this is a behavior change in existing code

---

## 5. User Flows

### Flow 1: Receiving a Digest Email
**Persona:** Show Notes user (single user)
**Entry Point:** Scheduled digest delivery

1. Digest job runs on schedule
2. Job queries for library episodes with `processing_status=ready` that became ready within the eligibility window (`digest_sent_at` or 24 hours ago, whichever is more recent)
3. If matching episodes exist, digest email is sent showing those episodes grouped by podcast
4. If no matching episodes, no email is sent (DIG-004)
5. **Success:** User sees only episodes they curated, with completed summaries
6. **Error:** If mailer fails, standard retry logic applies (no change from current behavior)

### Flow 2: New Episode Discovered by Feed Fetch
**Persona:** System (background job)
**Entry Point:** `FetchPodcastFeedJob` runs on schedule

1. Job fetches RSS feed and discovers a new episode
2. Job creates `Episode` record
3. Job creates `UserEpisode` inbox entry for each subscriber
4. Job does NOT enqueue transcription
5. Episode appears in the user's inbox with status "pending"
6. **Success:** Episode is visible in inbox, no API credits consumed
7. **Error:** Feed fetch errors handled as before (no change)

### Flow 3: User Adds Episode to Library
**Persona:** Show Notes user
**Entry Point:** Inbox or browse view

1. User clicks "Add to Library" on an inbox episode
2. `move_to_library!` sets location to library, processing_status to pending
3. `ProcessEpisodeJob` is enqueued
4. Job transcribes (AssemblyAI) then summarizes (Claude)
5. Episode appears in library as "ready" with summary
6. **Success:** Episode is transcribed and summarized, appears in next digest
7. **Error:** Episode shows error state in library with retry button (existing behavior)

---

## 6. UI Mockups / Wireframes

No UI changes required. The inbox and library views remain as-is. The only visible change is the digest email content, which is a backend query change — the email template structure can stay the same.

---

## 7. Backwards Compatibility

N/A — no API or client-facing changes. Single-platform web app with no external consumers.

---

## 8. Edge Cases & Business Rules

| Scenario | Expected Behavior | Platform |
|----------|-------------------|----------|
| Library has no ready episodes when digest runs | No digest email sent | Web |
| Episode was already transcribed (shared cache) when moved to library | `ProcessEpisodeJob` detects existing transcript/summary, skips API calls, marks ready immediately | Web |
| User moves episode to library, then archives before processing completes | Processing continues to completion — job operates on `UserEpisode` ID and does not re-check location. This is intentional: once processing starts, let it finish rather than adding guard logic. The cost is minimal for a single-user app. | Web |
| Inbox episodes that were auto-transcribed before this change | Existing transcripts/summaries remain on the `Episode` model — no data loss | Web |
| `DetectStuckProcessingJob` after Episode detection block is removed | Old episode-level stuck records are not actively detected. They will age out naturally since no new episode-level processing is enqueued. This is acceptable — the columns remain but the detection is removed alongside `AutoProcessEpisodeJob`. | Web |

---

## 9. Export Requirements

N/A.

---

## 10. Out of Scope

- Removing or migrating the `processing_status` columns from the `episodes` table — they're still useful
- Changing inbox UI or behavior — inbox still shows all new episodes from feeds
- Changing the digest delivery schedule or frequency
- Adding any new digest preferences or settings
- Retroactively un-transcribing episodes that were auto-processed
- Changing inbox processing status indicators — they'll mostly show "pending" now, but that's a separate UX decision

---

## 11. Open Questions

| # | Question | Status | Decision | Blocking? |
|---|----------|--------|----------|-----------|
| 1 | Should `AutoProcessEpisodeJob` be deleted entirely or left as dead code? | Resolved | Delete it. Single call site is being removed; dead code is confusing. Git history preserves the code. | No |
| 2 | Should the digest "since" window be based on `user_episodes.updated_at` or `digest_sent_at`? | Resolved | Use `digest_sent_at` with a 24-hour cap: `[digest_sent_at, 24.hours.ago].compact.max`. This prevents a backlog after gaps in delivery while still using the existing tracking field. | No |

> **All questions resolved — this PRD is ready for pipeline intake (after human review).**

---

## 12. Release Plan

### Phases

| Phase | What Ships | Flag | Audience |
|-------|-----------|------|----------|
| Phase 1 | All changes | None | Single user (personal app) |

### Feature Flag Strategy
Not needed — single-user personal app, direct deploy.

---

## 13. Assumptions

- The app continues to be single-user (no multi-tenancy concerns)
- `ProcessEpisodeJob` and `move_to_library!` already work correctly for library-triggered transcription
- The `digest_sent_at` tracking field on `User` still exists and is updated correctly
- Existing transcripts and summaries on `Episode` records are retained regardless of these changes

---

## Appendix: Linked Documents

| Document | Link |
|----------|------|
| Framing Doc | `pipeline-projects/inbox/library-scoped-processing.md` |
| Digest redesign commit | `c7fa7ff` (Feb 7, 2026) |
| Transcribe UX project | `pipeline-projects/tweak-transcribe-ux/` |
