---
pipeline_generated_at: "2026-02-19"
pipeline_project: "latest-at-top-digest"
---

# Pipeline Metrics — Latest-at-Top Digest Layout

> **Generated:** 2026-02-19
> **Branch:** `pipeline/latest-at-top-digest`
> **PR:** https://github.com/dpaola2/show-notes/pull/17
> **PR Status:** Open (not yet merged)

---

## 1. Stage Timeline

All times are 2026-02-19 Eastern (-0500).

| Stage | Name | Document | Started | Completed | Duration | Wait to Next |
|------:|------|----------|---------|-----------|----------|--------------|
| 0 | PRD | `prd.md` | 07:24 | 07:25 | 2m | 16m |
| 1 | Discovery | `discovery-report.md` | 07:41 | 07:41 | 1m | 6m |
| 2 | Architecture | `architecture-proposal.md` | 07:48 | 07:50 | 2m | 3m |
| 3 | Gameplan | `gameplan.md` | 07:54 | 07:54 | <1m | 4m |
| 4 | Test Generation | `test-coverage-matrix.md` | 07:59 | 08:10 | 11m | 4m |
| 5 | Implementation | `progress.md` | 08:14 | 08:55 | 41m | 11m |
| 6 | Review | `review-report.md` | 09:06 | 09:09 | 3m | 1m |
| 7 | QA Plan | `qa-plan.md` | 09:10 | 09:11 | 1m | 6m |
| — | PR Created | — | 09:17 | — | — | — |

**Notes:**
- Architecture approved at 07:52 (human review: 1m after completion)
- Gameplan approved immediately at completion (auto-approved)
- Wait-to-next for stages with human approval gates is measured from approval time

---

## 2. Implementation Breakdown (Stage 5)

| Milestone | Started | Completed | Duration | Gap from Prior | Commit |
|-----------|---------|-----------|----------|----------------|--------|
| M1 | 08:14 | 08:31 | 16m | 4m (after test gen) | `584d9d8` |
| M2 | 08:33 | 08:36 | 3m | 2m (after M1) | `584d9d8` |
| M3 | 08:38 | 08:40 | 2m | 3m (after M2) | `d9bee9d` |
| M4 | 08:49 | 08:55 | 6m | 9m (after M3) | `64a4ee3` |

- M1 and M2 were committed together in a single commit
- M4 had the longest inter-milestone gap (9m), likely due to review feedback or re-planning

---

## 3. Summary Stats

| Metric | Value |
|--------|-------|
| **Total lead time** (PRD start to PR created) | 1h 53m |
| **Total active agent time** (sum of stage durations) | 1h 1m |
| **Total wait / idle time** (lead time minus active time) | 52m |
| **Human review time** (architecture + gameplan approvals) | 1m |
| **Pipeline efficiency** (active time / lead time) | 54% |
| **Implementation share** (impl duration / active time) | 67% |
| **Longest stage** | Implementation (41m) |
| **Shortest stage** | Gameplan (<1m) |
| **Number of milestones** | 4 |
| **Review verdict** | Approved (0 blockers, 0 majors, 1 minor, 2 notes) |
