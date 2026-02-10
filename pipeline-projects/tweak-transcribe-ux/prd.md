---
pipeline_stage: 0
pipeline_stage_name: prd
pipeline_project: "tweak-transcribe-ux"
pipeline_started_at: "2026-02-09T18:34:28-0500"
pipeline_completed_at: "2026-02-09T18:35:07-0500"
---

# Transcription Resilience & Retry UX — PRD

|  |  |
| -- | -- |
| **Product** | Show Notes |
| **Version** | 2 |
| **Author** | Stage 0 (Pipeline) |
| **Date** | 2026-02-09 |
| **Status** | Draft — Review Required |
| **Platforms** | Web only |
| **Level** | 2 |

---

## 1. Executive Summary

**What:** Fix gaps in transcription error handling and add concurrency throttling. The app already has a `processing_status: :error` state, retry tracking fields (`retry_count`, `next_retry_at`, `last_error_at`), and a "Regenerate" button — but certain failure modes (especially AssemblyAI rate limits during bulk OPML import) bypass the existing error handling, leaving episodes permanently stuck in `transcribing` with no recovery path. This project closes those gaps and ensures both the Inbox and Library tabs surface errors with retry capability.

**Why:** Importing an OPML file with 100+ podcast subscriptions enqueued 100+ `ProcessEpisodeJob`s simultaneously, overwhelming AssemblyAI's rate limit. The resulting failures left episodes stuck in `transcribing` — the existing error handling didn't catch this failure mode, and the Inbox tab doesn't surface processing status at all.

**Key Design Principles:**
- Every transitional state (`transcribing`, `summarizing`) must have a timeout-based exit path — no permanent stuck states
- Bulk operations must be throttled to avoid overwhelming external APIs
- Error visibility and retry capability must be consistent across Inbox and Library tabs

---

## 2. Goals & Success Metrics

### Goals
- Close error handling gaps so ALL failure modes transition to `error` state (not stuck in `transcribing`)
- Throttle concurrent transcription jobs to prevent rate limit exhaustion during bulk import
- Surface processing status, errors, and retry in the Inbox tab (matching Library tab treatment)
- Detect and recover episodes stuck in transitional states via timeout

### Success Metrics

| Metric | Target | Timeframe |
|--------|--------|-----------|
| Episodes stuck in `transcribing` for >1 hour with no resolution path | 0 | Immediate |
| Bulk OPML import (100+ podcasts) completes without rate limit failures | Yes | Immediate |
| User-reported "stuck transcription" issues | 0 | 30 days |

---

## 3. Feature Requirements

### Error Handling Gaps

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| ERR-001 | `ProcessEpisodeJob` and `AutoProcessEpisodeJob` must catch ALL exception types (including AssemblyAI rate limit errors that currently slip through) and transition to `processing_status: :error` with a descriptive `processing_error` message | Web | Must |
| ERR-002 | Episodes stuck in `transcribing` or `summarizing` beyond a configurable timeout must be automatically detected and transitioned to `error` state with reason "Processing timed out" | Web | Must |
| ERR-003 | Rate limit errors from AssemblyAI should include actionable guidance in the error message (e.g., "AssemblyAI rate limit reached — wait a few minutes and retry, or check your plan's usage limits") | Web | Should |

### Concurrency Throttling

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| THR-001 | When multiple transcription jobs are enqueued simultaneously (e.g., during OPML import), the system must throttle concurrent requests to avoid overwhelming the AssemblyAI API | Web | Must |
| THR-002 | The throttling mechanism must work for both `ProcessEpisodeJob` (Library pathway) and `AutoProcessEpisodeJob` (Inbox/feed pathway) | Web | Must |
| THR-003 | The user should see clear feedback during throttled processing (e.g., episodes showing `pending` status with position awareness, not all showing `transcribing` simultaneously) | Web | Should |

### Inbox Tab — Error Visibility & Retry

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| INB-001 | The Inbox tab must display `processing_status` for each episode, matching the Library tab treatment (pending, transcribing, summarizing, ready, error indicators) | Web | Must |
| INB-002 | Episodes in `error` state in the Inbox must show the error reason and a "Retry" button | Web | Must |
| INB-003 | Clicking "Retry" in the Inbox re-enqueues the processing job and transitions the episode back to `pending` | Web | Must |
| INB-004 | The "Add to Library" action should work regardless of processing status — moving an errored episode to Library preserves its error state and retry capability | Web | Should |

### Library Tab — Existing UX Improvements

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| LIB-001 | The existing "Regenerate" button should be available for episodes in `error` state (verify this already works) | Web | Must |
| LIB-002 | If an episode has failed multiple times, the failure count should be visible alongside the error message | Web | Nice |

---

## 4. Platform-Specific Requirements

### Web (Rails)
- Both Inbox (`/inbox`) and Library (`/library`) tabs must show processing status and error states consistently
- Retry/Regenerate actions should use Turbo for seamless in-page updates (no full reload)
- Error state styling should be visually distinct from in-progress states (red/warning vs. neutral spinner)
- `AutoProcessEpisodeJob` (Inbox pathway) needs the same error handling rigor as `ProcessEpisodeJob` (Library pathway)

### iOS
- No changes required — Level 2 project

### Android
- No changes required — Level 2 project

---

## 5. User Flows

### Flow 1: OPML Import with Throttled Transcription

**Persona:** Show Notes user importing their podcast subscriptions
**Entry Point:** Import page

1. User uploads OPML file, subscribes to 100+ podcasts
2. User selects favorites → `process_favorites` enqueues `ProcessEpisodeJob` for each
3. System throttles: only N jobs process concurrently, rest queue as `pending`
4. Episodes show up in Library with `pending` → `transcribing` → `summarizing` → `ready` progression
5. If a job fails, episode transitions to `error` with descriptive message
6. User sees which episodes succeeded and which need retry
7. **Success:** All episodes eventually process (some via retry)

### Flow 2: Error in Inbox — User Retries

**Persona:** Show Notes user checking new episodes
**Entry Point:** Inbox tab

1. Feed fetch creates new episodes in user's Inbox
2. `AutoProcessEpisodeJob` begins transcription
3. Transcription fails (rate limit, timeout, API error)
4. Episode shows error indicator in Inbox with error reason
5. User clicks "Retry" button
6. Job re-enqueues, episode transitions to processing state
7. **Success:** Transcription completes, episode shows as ready in Inbox
8. User can then "Add to Library" as normal

### Flow 3: Stuck Job Detected Automatically

**Persona:** System (background process)
**Entry Point:** Timeout detection mechanism

1. Episode has been in `transcribing` or `summarizing` for longer than the configured timeout
2. System detects the stuck state and transitions to `error` with reason "Processing timed out"
3. User sees the error on their next visit to Inbox or Library
4. User can retry as in Flow 1 or 2

---

## 6. UI Mockups / Wireframes

### Inbox Tab — With Processing Status & Error States

```
┌─────────────────────────────────────────────────────────┐
│ Inbox                                                    │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ✓  Ep 87: Latest News         0:45:12                   │
│     [Add to Library]  [Skip]                             │
│                                                          │
│  ◌  Ep 52: Deep Dive           1:30:00                   │
│     Transcribing...                                      │
│     [Add to Library]  [Skip]                             │
│                                                          │
│  ⚠  Ep 14: Panel Chat          2:01:44                   │
│     Failed: rate limit exceeded  [Retry]                 │
│     [Add to Library]  [Skip]                             │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Library Tab — Error State (existing layout, with error visible)

```
┌─────────────────────────────────────────────────────────┐
│ Library                                                  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ✓  Episode 42: Great Interview         3:24:01          │
│     [View Summary]                                       │
│                                                          │
│  ⚠  Episode 40: Panel Discussion        2:01:44          │
│     Failed: rate limit exceeded (attempt 3)  [Retry]     │
│                                                          │
│  ◌  Episode 39: News Roundup            0:45:12          │
│     Pending (queued)...                                  │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

[NEEDS REVIEW — mockups generated from requirements. Verify these match the actual Inbox/Library layout and Tailwind styling conventions.]

---

## 7. Backwards Compatibility

N/A — no API or client-facing changes. Web-only feature with no external consumers.

### Migration Strategy
- Episodes currently stuck in `transcribing` state should be transitioned to `error` state as part of this project (rake task or migration)
- Existing `processing_error`, `retry_count`, `next_retry_at`, `last_error_at` fields on `UserEpisode` are already in place — no schema changes expected for error tracking
- No data loss — existing transcripts and summaries are unaffected

---

## 8. Edge Cases & Business Rules

| Scenario | Expected Behavior | Platform |
|----------|-------------------|----------|
| OPML import selects 100+ podcasts as favorites | Jobs throttled — only N run concurrently, rest queue as `pending` | Web |
| AssemblyAI rate limit hit mid-batch | Affected jobs transition to `error`, remaining queued jobs continue processing when rate limit resets | Web |
| Episode stuck in `transcribing` with no background job running (silent job death) | Timeout detection transitions to `error` with "Processing timed out" | Web |
| User clicks "Retry" while AssemblyAI is still rate-limited | Job re-enqueues, may fail again — user sees updated error with incremented retry count | Web |
| Multiple episodes fail simultaneously | All episodes show individual error states with retry buttons in both Inbox and Library | Web |
| User "Add to Library" on an errored Inbox episode | Episode moves to Library, preserving error state — retry button available in Library | Web |
| Concurrent retry attempts on same episode | Should be idempotent — only one processing job runs at a time | Web [INFERRED] |
| Episode transcript already exists (shared from another user) | `ProcessEpisodeJob` skips transcription, proceeds to summarization — no AssemblyAI call needed | Web |
| Feed fetch creates episode for multiple subscribers simultaneously | `AutoProcessEpisodeJob` runs at episode level, not per-user — one transcription call serves all subscribers | Web |

---

## 9. Export Requirements

N/A — no export functionality affected.

---

## 10. Out of Scope

- AssemblyAI usage dashboard or quota monitoring
- Alternative transcription provider fallback
- Bulk retry for multiple failed episodes at once (individual retry per episode is sufficient for now)
- Webhook/push notification when transcription fails
- Changing the existing exponential backoff parameters (current 5-retry / 60s-base scheme is fine)

---

## 11. Open Questions

| # | Question | Status | Decision | Blocking? |
|---|----------|--------|----------|-----------|
| 1 | What specific exception type does AssemblyAI raise on rate limit? Is it caught by the current `rescue` blocks in `ProcessEpisodeJob`? | Open | — | Yes |
| 2 | Does `AutoProcessEpisodeJob` have the same error handling as `ProcessEpisodeJob`, or is it missing retry logic? | Open | — | Yes |
| 3 | What timeout value is appropriate for stuck job detection? (AssemblyAI transcription of a 3-hour episode could legitimately take a while) | Open | — | No |
| 4 | Should the stuck-job detector be a recurring Solid Queue job, or integrated into the job itself (e.g., check age before processing)? | Open | — | No |

> **Blocking questions remain — Q1 and Q2 should be investigated in Stage 1 discovery.**

---

## 12. Release Plan

### Phases

| Phase | What Ships | Flag | Audience |
|-------|-----------|------|----------|
| Phase 1 | Error handling fixes + throttling + Inbox UX | None — direct ship | All users |

### Feature Flag Strategy
- No feature flag — this is a resilience fix, not a new user-facing feature. Ship directly.

---

## 13. Assumptions

- AssemblyAI is the only transcription provider (no multi-provider routing needed)
- Processing status lives on `UserEpisode` (confirmed: `processing_status` enum with `pending`, `downloading`, `transcribing`, `summarizing`, `ready`, `error`)
- Retry tracking fields already exist on `UserEpisode` (`retry_count`, `next_retry_at`, `last_error_at`, `processing_error`)
- Background jobs use Solid Queue (in-process via Puma, per PIPELINE.md)
- Transcripts and summaries are shared at the Episode level — if one user's processing succeeds, other users skip the API call
- The existing exponential backoff (5 retries, 60s base) is working correctly for errors it does catch — the problem is errors it doesn't catch

---

## Appendix: Linked Documents

| Document | Link |
|----------|------|
| Source notes | `~/projects/show-notes/pipeline-projects/inbox/tweak-transcribe-ux.md` |

## Appendix: Existing Architecture Reference

The following is the current state of relevant code, discovered during PRD refinement:

**State machine (`UserEpisode.processing_status`):** `pending(0)` → `downloading(1)` → `transcribing(2)` → `summarizing(3)` → `ready(4)`, with `error(5)` as a terminal state resettable via "Regenerate."

**Two processing pathways:**
- `ProcessEpisodeJob` — triggered by Library add or OPML import `process_favorites`. Operates on `user_episode_id`.
- `AutoProcessEpisodeJob` — triggered by `FetchPodcastFeedJob` for new feed episodes. Operates on `episode_id` (episode-level, not user-level).

**Existing error handling:** `ProcessEpisodeJob` catches `AssemblyAiClient::Error` and `ClaudeClient::RateLimitError`, increments `retry_count`, schedules retry with exponential backoff, and transitions to `error` after 5 failures. The gap: certain AssemblyAI failure modes may not raise `AssemblyAiClient::Error`.

**OPML import:** `OpmlImportService.process_favorites` enqueues one `ProcessEpisodeJob` per selected podcast (latest episode only). With 100+ selections, all jobs fire concurrently with no throttling.
