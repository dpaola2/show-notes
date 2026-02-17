---
pipeline_generated_at: "2026-02-17"
pipeline_product: "show-notes"
---

# Aggregate Pipeline Metrics — Show Notes

## Completed Projects

| Project | Level | Milestones | PR Created | PR Merged | Impl. Window |
|---------|-------|------------|------------|-----------|--------------|
| email-notifications | 1 | 2 | 2026-02-07 | 2026-02-07 | 4m |
| opml-import | 2 | 5 | 2026-02-07 | 2026-02-07 | 47m |
| onboarding | 2 | 6 | 2026-02-08 | 2026-02-08 | 11h 30m |
| long-lived-authentication | 1 | 2 | 2026-02-08 | 2026-02-08 | 7m |
| tweak-transcribe-ux | 2 | 6 | 2026-02-10 | 2026-02-10 | 43m |
| library-scoped-processing | 1 | 4 | 2026-02-17 | — | 32m |

All 6 projects have PRs. 5 of 6 are merged.

**PR URLs:**
- email-notifications: [#6](https://github.com/dpaola2/show-notes/pull/6)
- opml-import: [#7](https://github.com/dpaola2/show-notes/pull/7)
- onboarding: [#8](https://github.com/dpaola2/show-notes/pull/8)
- long-lived-authentication: [#9](https://github.com/dpaola2/show-notes/pull/9)
- tweak-transcribe-ux: [#13](https://github.com/dpaola2/show-notes/pull/13)
- library-scoped-processing: [#15](https://github.com/dpaola2/show-notes/pull/15)

---

## Implementation Speed

Milestone deltas are measured from one milestone commit/completion to the next. Projects with YAML frontmatter use `pipeline_m*_completed_at` timestamps. Projects without frontmatter use git author dates as proxies.

### email-notifications (Level 1, 2 milestones)

| Transition | Delta |
|------------|-------|
| M1 -> M2 | 4m |

### opml-import (Level 2, 5 milestones)

| Transition | Delta |
|------------|-------|
| M1 -> M2 | 11m |
| M2 -> M3 | 3m |
| M3 -> M4 | 21m |
| M4 -> M5 | 13m |

### onboarding (Level 2, 6 milestones)

| Transition | Delta |
|------------|-------|
| M1 -> M2 | 53m |
| M2 -> M3 | 30m |
| M3 -> M4 | — (verification only, no commit) |
| M4 -> M5 | 46m* |
| M5 -> M6 | 9h 3m** |

\* M4 has no commit (verification only); delta measured from M3 commit.
\** Overnight gap between M5 (22:28 Feb 7) and M6 (07:32 Feb 8).

### long-lived-authentication (Level 1, 2 milestones)

| Transition | Delta |
|------------|-------|
| M1 -> M2 | — (M2 is verification only, no commit) |

### tweak-transcribe-ux (Level 2, 6 milestones)

| Transition | Delta |
|------------|-------|
| M1 -> M2 | 7m |
| M2 -> M3 | 10m |
| M3 -> M4 | 3m |
| M4 -> M5 | 8m |
| M5 -> M6 | 4m |

### library-scoped-processing (Level 1, 4 milestones)

| Transition | Delta |
|------------|-------|
| M1 -> M2 | 7m |
| M2 -> M3 | 6m |
| M3 -> M4 | 14m |

---

## Pipeline Throughput

| Metric | Value |
|--------|-------|
| Total projects completed (PR created) | 6 |
| Total projects merged | 5 |
| Total milestones implemented | 25 |
| Median milestone delta (same-day) | 9m |
| Fastest milestone delta | 3m (opml-import M2->M3, tweak-transcribe-ux M3->M4) |
| Slowest same-day milestone delta | 53m (onboarding M1->M2) |
| Shortest implementation window | 4m (email-notifications) |
| Longest implementation window | 11h 30m (onboarding, includes overnight gap) |
| Longest same-day implementation window | 47m (opml-import) |
| Avg milestones per project | 4.2 |
| Avg PR merge time (merged only) | 13m |

### Milestone delta distribution (same-day, excluding overnight)

All 16 same-day milestone deltas sorted:

| Rank | Delta | Project |
|------|-------|---------|
| 1 | 3m | opml-import M2->M3 |
| 2 | 3m | tweak-transcribe-ux M3->M4 |
| 3 | 4m | email-notifications M1->M2 |
| 4 | 4m | tweak-transcribe-ux M5->M6 |
| 5 | 6m | library-scoped-processing M2->M3 |
| 6 | 7m | tweak-transcribe-ux M1->M2 |
| 7 | 7m | library-scoped-processing M1->M2 |
| 8 | 8m | tweak-transcribe-ux M4->M5 |
| 9 | 10m | tweak-transcribe-ux M2->M3 |
| 10 | 11m | opml-import M1->M2 |
| 11 | 13m | opml-import M4->M5 |
| 12 | 14m | library-scoped-processing M3->M4 |
| 13 | 21m | opml-import M3->M4 |
| 14 | 30m | onboarding M2->M3 |
| 15 | 46m | onboarding M4->M5 |
| 16 | 53m | onboarding M1->M2 |

**Median (of 16):** 9m (average of rank 8 and 9: 8m and 10m)

---

## In-Progress Projects

None. All 6 projects have PRs created. 1 project (library-scoped-processing) is awaiting merge.

---

## Data Quality Notes

- **email-notifications, opml-import, onboarding, long-lived-authentication:** These 4 projects pre-date DORA frontmatter instrumentation. Milestone timestamps are derived from git commit author dates, which reflect commit time (not milestone start time). Implementation windows may undercount time spent on milestones that required multiple attempts before committing.
- **tweak-transcribe-ux, library-scoped-processing:** These 2 projects have YAML frontmatter with `pipeline_m*_started_at` and `pipeline_m*_completed_at` timestamps, providing precise milestone duration data.
- **Verification-only milestones:** onboarding M4 and long-lived-authentication M2 produced no commits (verification only). Their deltas are excluded from the distribution. For onboarding, the M4->M5 delta is measured from M3 completion instead.
- **Overnight gap:** onboarding spans an overnight break (M5 at 22:28 Feb 7, M6 at 07:32 Feb 8). The M5->M6 delta of 9h 3m includes ~8h of non-working time. This transition is excluded from the same-day distribution; the 46m figure for onboarding M4->M5 uses M3->M5 elapsed time instead.
- **Level field:** email-notifications and long-lived-authentication PRDs specify Level 1. opml-import and tweak-transcribe-ux specify Level 2. onboarding suggests Level 2 but uses "CONFIRM" language. library-scoped-processing specifies Level 1.
- **PR merge times:** Measured from GitHub `createdAt` to `mergedAt`. library-scoped-processing PR is open (not yet merged).
- **Implementation window:** For projects with frontmatter, measured from `pipeline_m1_started_at` to last `pipeline_m*_completed_at`. For projects without frontmatter, measured from first milestone commit to last milestone commit (underestimates actual time since it excludes time before the first commit).
