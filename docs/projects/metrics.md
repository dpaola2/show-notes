---
pipeline_generated_at: "2026-02-18"
pipeline_product: "show-notes"
---

# Aggregate Pipeline Metrics — Show Notes

## Completed Projects

| Project | Milestones | PR | Implementation Window |
|---------|:---:|---|----|
| email-notifications | 2 | [#6](https://github.com/dpaola2/show-notes/pull/6) | 4m (git) |
| opml-import | 5 | [#7](https://github.com/dpaola2/show-notes/pull/7) | 47m (git) |
| onboarding | 6 | [#8](https://github.com/dpaola2/show-notes/pull/8) | 11h 30m (git, includes overnight) |
| long-lived-authentication | 2 | [#9](https://github.com/dpaola2/show-notes/pull/9) | 7m (git) |
| tweak-transcribe-ux | 6 | [#13](https://github.com/dpaola2/show-notes/pull/13) | 42m 30s (live) |
| library-scoped-processing | 4 | [#15](https://github.com/dpaola2/show-notes/pull/15) | 31m 37s (live) |
| shareable-episode-cards | 5 | [#16](https://github.com/dpaola2/show-notes/pull/16) | 2h 4m 11s (live) |

Implementation window = wall clock from first milestone start to last milestone end (excludes M0 discovery and PR creation). "(git)" = derived from git commit timestamps; "(live)" = from YAML frontmatter start/end timestamps.

---

## Pipeline Throughput

| Metric | Value |
|--------|------:|
| Total completed projects | 7 |
| Total implementation milestones | 30 |
| Projects with PR | 7 |
| Projects with live timing | 3 |
| Avg milestones per project | 4.3 |

---

## Agent Speed Highlights

Three projects have live per-milestone timing data from YAML frontmatter.

### shareable-episode-cards (5 milestones, 2026-02-18)

| Milestone | Description | Duration |
|-----------|-------------|----------|
| M1 | Data Model, Public Page & OG Meta Tags | 8m 54s |
| M2 | OG Image Generation | 35m 16s |
| M3 | Share UI, Tracking & UTM Attribution | 27m 16s |
| M4 | QA Test Data | 2m 16s |
| M5 | Edge Cases, Empty States & Polish | 3m 19s |

- **Median:** 8m 54s
- **Fastest:** M4 -- QA Test Data (2m 16s)
- **Slowest:** M2 -- OG Image Generation (35m 16s)

### tweak-transcribe-ux (6 milestones, 2026-02-10)

| Milestone | Description | Duration |
|-----------|-------------|----------|
| M1 | Data Model & Core Error Handling | 10m 42s |
| M2 | Stuck Job Detection | 3m 14s |
| M3 | Inbox Tab -- Processing Status & Retry | 4m 30s |
| M4 | Library Tab -- Enhanced Error Display & Retry | 1m 27s |
| M5 | QA Test Data | 5m 0s |
| M6 | Edge Cases & Polish | 3m 0s |

- **Median:** 3m 52s
- **Fastest:** M4 -- Library Tab (1m 27s)
- **Slowest:** M1 -- Data Model & Core Error Handling (10m 42s)

### library-scoped-processing (4 milestones, 2026-02-17)

| Milestone | Description | Duration |
|-----------|-------------|----------|
| M1 | Shared Scope & Digest Query Change | 5m 5s |
| M2 | Remove Auto-Processing from Feed Fetch | 3m 30s |
| M3 | QA Test Data | 1m 48s |
| M4 | Edge Cases & Polish | 10m 23s |

- **Median:** 4m 17s
- **Fastest:** M3 -- QA Test Data (1m 48s)
- **Slowest:** M4 -- Edge Cases & Polish (10m 23s)

### Cross-Project Summary (15 milestones with live timing)

All 15 milestone durations sorted:

| Rank | Duration | Project | Milestone |
|------|----------|---------|-----------|
| 1 | 1m 27s | tweak-transcribe-ux | M4 |
| 2 | 1m 48s | library-scoped-processing | M3 |
| 3 | 2m 16s | shareable-episode-cards | M4 |
| 4 | 3m 0s | tweak-transcribe-ux | M6 |
| 5 | 3m 14s | tweak-transcribe-ux | M2 |
| 6 | 3m 19s | shareable-episode-cards | M5 |
| 7 | 3m 30s | library-scoped-processing | M2 |
| 8 | 4m 30s | tweak-transcribe-ux | M3 |
| 9 | 5m 0s | tweak-transcribe-ux | M5 |
| 10 | 5m 5s | library-scoped-processing | M1 |
| 11 | 8m 54s | shareable-episode-cards | M1 |
| 12 | 10m 23s | library-scoped-processing | M4 |
| 13 | 10m 42s | tweak-transcribe-ux | M1 |
| 14 | 27m 16s | shareable-episode-cards | M3 |
| 15 | 35m 16s | shareable-episode-cards | M2 |

**Overall median (of 15):** 4m 30s (rank 8)
**Fastest:** 1m 27s (tweak-transcribe-ux M4)
**Slowest:** 35m 16s (shareable-episode-cards M2)

---

## Data Quality Notes

| Project | Timing Source | Notes |
|---------|-------------|-------|
| shareable-episode-cards | **Live** | YAML frontmatter with per-milestone `pipeline_m*_started_at` / `pipeline_m*_completed_at` |
| tweak-transcribe-ux | **Live** | YAML frontmatter with per-milestone start/end timestamps |
| library-scoped-processing | **Live** | YAML frontmatter with per-milestone start/end timestamps |
| email-notifications | **Git** | No YAML frontmatter; implementation window derived from git commit author dates |
| opml-import | **Git** | No YAML frontmatter; implementation window derived from git commit author dates |
| onboarding | **Git** | No YAML frontmatter; implementation window derived from git commit author dates; includes overnight gap |
| long-lived-authentication | **Git** | No YAML frontmatter; implementation window derived from git commit author dates |

No projects have the `pipeline_backfilled` field. The four git-only projects predate the pipeline's timing instrumentation -- their progress files record completion dates per milestone but not machine-readable start/end timestamps. Git-derived windows undercount time spent on milestones that required multiple attempts before committing.
