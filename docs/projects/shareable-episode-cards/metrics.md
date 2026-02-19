# Pipeline Metrics — shareable-episode-cards

> Generated: 2026-02-18
> Data quality: live (all stages have pipeline timestamps)

## Stage Timeline

| Stage | Document | Started | Completed | Duration | Wait → Next |
|-------|----------|---------|-----------|----------|-------------|
| 0: PRD | prd.md | 08:19 | 08:22 | 2m | 13m |
| 1: Discovery | discovery-report.md | 08:35 | 08:37 | 2m | 13m |
| 2: Architecture | architecture-proposal.md | 08:50 | 08:51 | 1m | — |
| 2→3: Human Review | — | 08:51 | approved 09:11 | 21m | 2m |
| 3: Gameplan | gameplan.md | 09:13 | 09:14 | 1m | — |
| 3→4: Human Review | — | 09:14 | approved 09:32 | 18m | 0m |
| 4: Test Generation | test-coverage-matrix.md | 09:32 | 09:40 | 9m | 7h 21m |
| 5: Implementation | progress.md | — | — | — | — |
| 5/M1 | — | 17:02 | 17:10 | 9m | 5m |
| 5/M2 | — | 17:16 | 17:51 | 35m | 13m |
| 5/M3 | — | 18:04 | 18:31 | 27m | 17m |
| 5/M4 | — | 18:48 | 18:50 | 2m | 12m |
| 5/M5 | — | 19:02 | 19:06 | 3m | 3m |
| 6: Review | review-report.md | 19:08 | 19:11 | 3m | 5m |
| 7: QA Plan | qa-plan.md | 19:16 | 19:18 | 2m | 9m |
| PR Created | — | — | 19:27 | — | 24m |
| PR Merged | — | — | 19:51 | — | — |

All times are 2026-02-18 Eastern (UTC-5).

## Summary

| Metric | Value |
|--------|-------|
| **Total Lead Time** (PRD start → PR merge) | 11h 31m |
| **Active Agent Time** | 1h 37m |
| **Human Review Time** | 38m |
| **Idle/Queue Time** | 9h 17m |
| **Agent Efficiency** | 14.8% |

## Implementation Breakdown

| Milestone | Description | Duration | Files | Tests |
|-----------|-------------|----------|-------|-------|
| M1 | Data Model, Public Page & OG Meta Tags | 9m | 12 | 53 |
| M2 | OG Image Generation | 35m | 4 | 19 |
| M3 | Share UI, Tracking & UTM Attribution | 27m | 8 | 39 |
| M4 | QA Test Data | 2m | 1 | 0 |
| M5 | Edge Cases, Empty States & Polish | 3m | 1 | 53 |
| **Total** | | **1h 16m** | **26** | **164** |

Implementation elapsed time (M1 start → M5 end): 2h 4m
Implementation active time (sum of milestones): 1h 16m
Implementation efficiency (active / elapsed): 61.5%

## PR & Review

| Field | Value |
|-------|-------|
| PR | [#16](https://github.com/dpaola2/show-notes/pull/16) |
| Review verdict | Approved (0 blockers, 0 majors, 3 minors, 3 notes) |
| PR created → merged | 24m |
| Commits | `e00eeae`, `ad0f521`, `25e550d`, `fd8b82b`, `87d1d1f` |

## Data Quality Notes

- All stages have live `pipeline_started_at` and `pipeline_completed_at` timestamps (no backfilled data)
- Implementation stage (5) has no top-level started/completed — uses per-milestone timestamps instead
- The 7h 21m gap between test generation (stage 4) and implementation (stage 5/M1) is the primary contributor to idle time, likely representing a human scheduling gap rather than pipeline overhead
- PR merge time sourced from GitHub API (`gh pr view`); all other timestamps from document frontmatter
