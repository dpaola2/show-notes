---
pipeline_generated_at: "2026-02-18"
pipeline_product: "show-notes"
---

# Aggregate Pipeline Metrics — Show Notes

> Generated: 2026-02-18
> Projects: 7 completed, 7 merged

---

## Completed Projects

| Project | Date | Milestones | PR | Impl Window | Impl Active | PR Lifetime |
|---------|------|:---:|---|-------------|-------------|-------------|
| email-notifications | 2026-02-07 | 2 | [#6](https://github.com/dpaola2/show-notes/pull/6) | 4m (git) | — | 19m |
| opml-import | 2026-02-07 | 5 | [#7](https://github.com/dpaola2/show-notes/pull/7) | 47m (git) | — | 1h 18m |
| onboarding | 2026-02-08 | 6 | [#8](https://github.com/dpaola2/show-notes/pull/8) | 11h 30m (git\*) | — | 16m |
| long-lived-authentication | 2026-02-08 | 2 | [#9](https://github.com/dpaola2/show-notes/pull/9) | 7m (git) | — | 10m |
| tweak-transcribe-ux | 2026-02-10 | 6 | [#13](https://github.com/dpaola2/show-notes/pull/13) | 43m (live) | 28m | 4m |
| library-scoped-processing | 2026-02-17 | 4 | [#15](https://github.com/dpaola2/show-notes/pull/15) | 32m (live) | 21m | 12m |
| shareable-episode-cards | 2026-02-18 | 5 | [#16](https://github.com/dpaola2/show-notes/pull/16) | 2h 4m (live) | 1h 16m | 24m |

Implementation window = wall clock from M1 start → last milestone end. Implementation active = sum of milestone durations. "(git)" = derived from git commit timestamps; "(live)" = from YAML frontmatter. \*onboarding includes an overnight gap.

---

## Pipeline Throughput

| Metric | Value |
|--------|------:|
| Total completed projects | 7 |
| Total implementation milestones | 30 |
| All PRs merged | Yes |
| Projects with live timing | 3 |
| Avg milestones per project | 4.3 |
| Median PR lifetime (create → merge) | 16m |

---

## Full Pipeline Metrics (3 projects with live timing)

| Metric | shareable-episode-cards | tweak-transcribe-ux | library-scoped-processing |
|--------|----------------------:|--------------------:|-------------------------:|
| **Total Lead Time** | 11h 31m | 13h 16m | 3h 5m |
| **Active Agent Time** | 1h 37m | 34m | 42m |
| **Human Review Time** | 38m | 2h 27m | 1h 14m |
| **Idle/Queue Time** | 9h 17m | 10h 15m | 56m |
| **Agent Efficiency** | 14.8% | 5.2% | 42.9% |
| **Impl Window** | 2h 4m | 43m | 32m |
| **Impl Active** | 1h 16m | 28m | 21m |
| **Impl Efficiency** | 61.5% | 65.1% | 65.6% |
| **Milestones** | 5 | 6 | 4 |
| **PR Lifetime** | 24m | 4m | 12m |

- **Total Lead Time** = PRD start → PR merge
- **Agent Efficiency** = Active Agent Time / (Active Agent Time + Idle/Queue Time)
- **Impl Efficiency** = Implementation active time / Implementation window

### What drives low agent efficiency?

The dominant factor is **scheduling gaps** — time between pipeline stages where the human hasn't started the next step. The largest gaps:

| Project | Gap | Duration | Context |
|---------|-----|----------|---------|
| tweak-transcribe-ux | Discovery → Architecture | 2h 28m | Evening break |
| tweak-transcribe-ux | Architecture approved → Gameplan | 9h 7m | Overnight |
| shareable-episode-cards | Test Gen → Implementation | 7h 21m | Afternoon break |
| library-scoped-processing | Architecture review | 1h 6m | Human review wait |

Implementation efficiency (61-66%) is much higher, showing that once the agent is running milestones, most time is productive.

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

**Overall median (of 15):** 4m 30s
**Mean:** 8m 24s
**Fastest:** 1m 27s (tweak-transcribe-ux M4)
**Slowest:** 35m 16s (shareable-episode-cards M2)

---

## PR Lifecycle

| PR | Project | Created → Merged | State |
|----|---------|-----------------|-------|
| [#6](https://github.com/dpaola2/show-notes/pull/6) | email-notifications | 19m | Merged |
| [#7](https://github.com/dpaola2/show-notes/pull/7) | opml-import | 1h 18m | Merged |
| [#8](https://github.com/dpaola2/show-notes/pull/8) | onboarding | 16m | Merged |
| [#9](https://github.com/dpaola2/show-notes/pull/9) | long-lived-authentication | 10m | Merged |
| [#13](https://github.com/dpaola2/show-notes/pull/13) | tweak-transcribe-ux | 4m | Merged |
| [#15](https://github.com/dpaola2/show-notes/pull/15) | library-scoped-processing | 12m | Merged |
| [#16](https://github.com/dpaola2/show-notes/pull/16) | shareable-episode-cards | 24m | Merged |

**Median PR lifetime:** 16m
**Mean PR lifetime:** 23m

---

## Data Quality Notes

| Project | Timing Source | Notes |
|---------|-------------|-------|
| shareable-episode-cards | **Live** | Full pipeline timestamps in YAML frontmatter |
| tweak-transcribe-ux | **Live** | Full pipeline timestamps in YAML frontmatter |
| library-scoped-processing | **Live** | Full pipeline timestamps; architecture/gameplan `approved_at` is date-only precision |
| email-notifications | **Git** | Implementation window derived from git commit author dates |
| opml-import | **Git** | Implementation window derived from git commit author dates |
| onboarding | **Git** | Implementation window derived from git commit author dates; includes overnight gap |
| long-lived-authentication | **Git** | Implementation window derived from git commit author dates |

The four git-only projects predate the pipeline's timing instrumentation — their progress files record completion dates per milestone but not machine-readable start/end timestamps. Git-derived windows may undercount time spent on milestones that required multiple attempts before committing. Full pipeline metrics (lead time, agent efficiency, human review time) are only available for the three live-timed projects.
