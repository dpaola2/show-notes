---
pipeline_generated_at: "2026-02-19"
pipeline_product: "show-notes"
---

# Pipeline Metrics — show-notes

Aggregate metrics across all completed and in-progress pipeline projects.

---

## 1. Completed Projects

| # | Project | Level | Milestones | Impl Time | PR | PR Created | PR Merged | Review Time |
|---|---------|:-----:|:----------:|:---------:|:--:|:----------:|:---------:|:-----------:|
| 1 | email-notifications | 1 | 2 (M1–M2) | — | [#6](https://github.com/dpaola2/show-notes/pull/6) | 2026-02-07 | 2026-02-07 | 18m |
| 2 | opml-import | 2 | 5 (M1–M5) | — | [#7](https://github.com/dpaola2/show-notes/pull/7) | 2026-02-07 | 2026-02-07 | 1h 18m |
| 3 | onboarding | 2 | 6 (M1–M6) | — | [#8](https://github.com/dpaola2/show-notes/pull/8) | 2026-02-08 | 2026-02-08 | 15m |
| 4 | long-lived-authentication | 1 | 2 (M1–M2) | — | [#9](https://github.com/dpaola2/show-notes/pull/9) | 2026-02-08 | 2026-02-08 | 9m |
| 5 | tweak-transcribe-ux | 2 | 6 (M1–M6) | 42m | [#13](https://github.com/dpaola2/show-notes/pull/13) | 2026-02-10 | 2026-02-10 | 3m |
| 6 | library-scoped-processing | 1 | 4 (M1–M4) | 31m | [#15](https://github.com/dpaola2/show-notes/pull/15) | 2026-02-17 | 2026-02-17 | 12m |
| 7 | shareable-episode-cards | 3 | 5 (M1–M5) | 2h 4m | [#16](https://github.com/dpaola2/show-notes/pull/16) | 2026-02-18 | 2026-02-19 | 23m |

- **Impl Time** = wall-clock from M1 start to final milestone completion (from pipeline YAML frontmatter). Projects 1--4 predate timing instrumentation.
- **Review Time** = PR creation to merge on GitHub (includes CI, human review, and any follow-up commits).
- All 7 completed projects were merged within hours of opening.

---

## 2. Implementation Speed

Timed projects only (projects 5--8 have per-milestone `pipeline_m*_started_at`/`pipeline_m*_completed_at` timestamps).

### Per-Project Summary

| Project | Level | Milestones | Impl Time | Time to PR | Avg/Milestone |
|---------|:-----:|:----------:|:---------:|:----------:|:-------------:|
| library-scoped-processing | 1 | 4 | 31m | 1h 11m | 8m |
| latest-at-top-digest | 1 | 4 | 40m | 1h 2m | 10m |
| tweak-transcribe-ux | 2 | 6 | 42m | 44m | 7m |
| shareable-episode-cards | 3 | 5 | 2h 4m | 2h 25m | 25m |

### Per-Milestone Breakdown

**tweak-transcribe-ux** (6 milestones, 42m total)

| Milestone | Duration | Description |
|-----------|:--------:|-------------|
| M1 | 10m | Data Model & Core Error Handling |
| M2 | 3m | Stuck Job Detection |
| M3 | 4m | Inbox Tab -- Processing Status & Retry |
| M4 | 1m | Library Tab -- Enhanced Error Display & Retry |
| M5 | 5m | QA Test Data |
| M6 | 3m | Edge Cases & Polish |

**library-scoped-processing** (4 milestones, 31m total)

| Milestone | Duration | Description |
|-----------|:--------:|-------------|
| M1 | 5m | Shared Scope & Digest Query Change |
| M2 | 3m | Remove Auto-Processing from Feed Fetch |
| M3 | 1m | QA Test Data |
| M4 | 10m | Edge Cases & Polish |

**shareable-episode-cards** (5 milestones, 2h 4m total)

| Milestone | Duration | Description |
|-----------|:--------:|-------------|
| M1 | 8m | Data Model, Public Page & OG Meta Tags |
| M2 | 35m | OG Image Generation |
| M3 | 27m | Share UI, Tracking & UTM Attribution |
| M4 | 2m | QA Test Data |
| M5 | 3m | Edge Cases & Polish |

**latest-at-top-digest** (4 milestones, 40m total)

| Milestone | Duration | Description |
|-----------|:--------:|-------------|
| M1 | 16m | Scope & Mailer Data Layer |
| M2 | 2m | Email Templates |
| M3 | 2m | QA Test Data |
| M4 | 5m | Edge Cases & Polish |

### Cross-Project Milestone Ranking (19 milestones with live timing)

| Rank | Duration | Project | Milestone |
|:----:|:--------:|---------|-----------|
| 1 | 1m | library-scoped-processing | M3 |
| 2 | 1m | tweak-transcribe-ux | M4 |
| 3 | 2m | shareable-episode-cards | M4 |
| 4 | 2m | latest-at-top-digest | M2 |
| 5 | 2m | latest-at-top-digest | M3 |
| 6 | 3m | tweak-transcribe-ux | M2 |
| 7 | 3m | tweak-transcribe-ux | M6 |
| 8 | 3m | library-scoped-processing | M2 |
| 9 | 3m | shareable-episode-cards | M5 |
| 10 | 4m | tweak-transcribe-ux | M3 |
| 11 | 5m | tweak-transcribe-ux | M5 |
| 12 | 5m | library-scoped-processing | M1 |
| 13 | 5m | latest-at-top-digest | M4 |
| 14 | 8m | shareable-episode-cards | M1 |
| 15 | 10m | tweak-transcribe-ux | M1 |
| 16 | 10m | library-scoped-processing | M4 |
| 17 | 16m | latest-at-top-digest | M1 |
| 18 | 27m | shareable-episode-cards | M3 |
| 19 | 35m | shareable-episode-cards | M2 |

| Metric | Value |
|--------|------:|
| **Median milestone duration** | 4m |
| **Mean milestone duration** | 7m |
| **Fastest milestone** | 1m (library-scoped M3, tweak-transcribe-ux M4) |
| **Slowest milestone** | 35m (shareable-episode-cards M2 -- OG Image Generation) |

### Aggregate Implementation Speed

| Metric | Value |
|--------|------:|
| **Fastest project** | 31m (library-scoped-processing, Level 1) |
| **Slowest project** | 2h 4m (shareable-episode-cards, Level 3) |
| **Median project** | 41m |
| **Mean project** | 59m |

---

## 3. Pipeline Throughput

| Metric | Value |
|--------|------:|
| **Total completed projects** | 7 |
| **Total in-progress projects** | 1 |
| **Total implementation milestones** | 34 (across 8 projects, excluding M0) |
| **Date range** | 2026-02-07 to 2026-02-19 (13 calendar days) |
| **Throughput** | 0.5 projects/day, 2.6 milestones/day |
| **Same-day merge rate** | 100% (7/7 completed PRs) |

### PR Review Times (7 merged PRs)

| Metric | Value |
|--------|------:|
| **Median** | 15m |
| **Mean** | 23m |
| **Fastest** | 3m (tweak-transcribe-ux) |
| **Slowest** | 1h 18m (opml-import) |

### By Level

| Level | Projects | Milestones | Examples |
|:-----:|:--------:|:----------:|---------|
| 1 | 4 | 12 | email-notifications, long-lived-auth, library-scoped, latest-at-top-digest |
| 2 | 3 | 17 | opml-import, onboarding, tweak-transcribe-ux |
| 3 | 1 | 5 | shareable-episode-cards |

---

## 4. In-Progress Projects

| Project | Level | Milestones | Status | PR |
|---------|:-----:|:----------:|--------|:--:|
| latest-at-top-digest | 1 | 4 (M1--M4) | All milestones complete; PR open | [#17](https://github.com/dpaola2/show-notes/pull/17) |

All 4 implementation milestones are complete (40m impl time). PR #17 was created 2026-02-19 and is awaiting review/merge.

---

## 5. Data Quality Notes

1. **Early projects lack timing data.** Projects 1--4 (email-notifications, opml-import, onboarding, long-lived-authentication) were completed before the pipeline added per-milestone `pipeline_m*_started_at`/`pipeline_m*_completed_at` timestamps. Implementation times are unavailable for these projects.

2. **Onboarding level inferred.** The onboarding PRD lists level as `[CONFIRM -- suggesting Level 2]`. Level 2 was used based on scope (models, jobs, mailers, controllers, views).

3. **Long-lived-authentication level inferred.** The PRD lists level as `[CONFIRM -- suggested: 1]`. Level 1 was used based on scope (session config + redirect only).

4. **PR review times are GitHub timestamps.** They measure wall-clock time from PR creation to merge event, which includes CI checks, human review, and any follow-up commits. They do not isolate pure human review time.

5. **latest-at-top-digest classified as in-progress.** All milestones are complete and the PR is created, but it is not yet merged.

6. **M0 excluded from counts.** All milestone counts and timing data cover implementation milestones only (M1+). M0 (Discovery & Alignment) is a pre-implementation pipeline stage.

7. **Milestone durations are wall-clock.** They include time between `pipeline_m*_started_at` and `pipeline_m*_completed_at`, which covers spec runs, spec fixes, and inter-milestone transitions.

8. **No parsing failures.** All 8 project directories with progress.md files were parsed successfully.
