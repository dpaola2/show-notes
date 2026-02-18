# Pipeline Metrics — library-scoped-processing

> Generated: 2026-02-17
> Pipeline branch: `pipeline/library-scoped-processing`
> PR: https://github.com/dpaola2/show-notes/pull/15

---

## 1. Stage Timeline

| Stage | Document | Started | Completed | Duration | Wait to Next |
|-------|----------|---------|-----------|----------|--------------|
| Stage 0 (PRD) | prd.md | 08:17:48 | 08:19:27 | 1m | 4m |
| Stage 1 (Discovery) | discovery-report.md | 08:23:44 | 08:26:04 | 2m | 1m |
| Stage 2 (Architecture) | architecture-proposal.md | 08:28:01 | 08:28:32 | 31s | 1h 6m |
| *Architecture review* | — | — | approved 2026-02-17 | *1h 6m* | — |
| Stage 3 (Gameplan) | gameplan.md | 09:34:41 | 09:35:16 | 35s | 8m |
| *Gameplan review* | — | — | approved 2026-02-17 | *8m* | — |
| Stage 4 (Test Gen) | test-coverage-matrix.md | 09:43:17 | 09:53:41 | 10m | 5m |
| Stage 5 (Implementation) | progress.md | 09:58:46 | 10:30:23 | 31m | 26m |
| Stage 7 (QA Plan) | qa-plan.md | 10:56:53 | 11:03:10 | 6m | 7m |
| PR Created | — | 11:10:41 | — | — | — |

All times are EST (UTC-5) on 2026-02-17.

---

## 2. Implementation Breakdown

| Milestone | Description | Started | Completed | Duration | Delta from Prior | Commit |
|-----------|-------------|---------|-----------|----------|------------------|--------|
| M1 | Shared Scope & Digest Query Change | 09:58:46 | 10:03:51 | 5m | — | `b65d265` |
| M2 | Remove Auto-Processing from Feed Fetch | 10:07:23 | 10:10:53 | 3m | 3m | `67e0c25` |
| M3 | QA Test Data | 10:14:40 | 10:16:28 | 1m | 3m | `f282dcc` |
| M4 | Edge Cases & Polish | 10:20:00 | 10:30:23 | 10m | 3m | `fad60cb` |

---

## 3. Summary

| Metric | Value |
|--------|-------|
| **Total lead time** (PRD start to PR created) | 2h 52m |
| **Active agent time** (sum of stage + milestone durations) | 42m |
| **Human review time** (architecture + gameplan review waits) | 1h 14m |
| **Implementation window** (M1 start to M4 complete) | 31m |
| **PR review time** | pending (not yet merged) |
| **Idle/transition time** | 56m |

Breakdown of human review time:
- Architecture review: 1h 6m (Stage 2 completed to Stage 3 started)
- Gameplan review: 8m (Stage 3 completed to Stage 4 started)

---

## 4. Data Quality Notes

- **Architecture and gameplan `approved_at`** have date-only precision (`2026-02-17`), not timestamps. Human review durations are computed as the gap between stage completion and the next stage's start, which captures actual wall-clock wait.
- **test-coverage-matrix.md** was read from the git branch (`pipeline/library-scoped-processing`) since the file does not exist on the main branch.
- **PR not yet merged** as of report generation. PR review time will be computable once the PR is merged.
- **All stages completed on the same day** (2026-02-17). This was a single-session pipeline run.
- **Idle/transition time** (56m) is computed as total lead time minus active agent time minus human review time. This includes inter-stage waits not attributed to human review (e.g., 26m between M4 completion and QA plan start, 5m between test generation and M1 start).
