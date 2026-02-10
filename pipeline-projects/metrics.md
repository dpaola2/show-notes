---
pipeline_generated_at: "2026-02-10"
pipeline_product: "show-notes"
---

# Pipeline Metrics — Show Notes

> **Generated:** 2026-02-10
> **Product:** Show Notes (Rails 8.1 web app)
> **Pipeline Repo:** `~/projects/orangeqc/agent-pipeline`
> **Target Repo:** `~/projects/show-notes`

---

## Completed Projects

| Project | PR | Milestones | Lead Time | Active Time | Status |
|---------|----|-----------:|----------:|------------:|--------|
| opml-import | [#1](https://github.com/dpaola2/show-notes/pull/1) | 5 | — | — | Merged |
| email-notifications | — | 2 | — | — | Ready for PR |
| long-lived-authentication | — | 2 | — | — | Ready for PR |
| onboarding | — | 6 | — | — | Ready for PR |
| tweak-transcribe-ux | [#13](https://github.com/dpaola2/show-notes/pull/13) | 6 | 13h 16m | 34m | Open |

**Note:** Lead time and active time metrics are only available for tweak-transcribe-ux (first project with comprehensive timestamp tracking in frontmatter).

---

## Implementation Speed

| Metric | Value | Notes |
|--------|------:|-------|
| **Average milestones per project** | 4.2 | Range: 2 (email-notifications, long-lived-authentication) to 6 (onboarding, tweak-transcribe-ux) |
| **Implementation time per milestone** | 7m | Based on tweak-transcribe-ux: 42m 30s across 6 milestones |
| **Test coverage per project** | 75+ tests | Based on tweak-transcribe-ux (75 tests), onboarding (126 tests) |
| **Average files changed per project** | 18 | Based on tweak-transcribe-ux (18 files modified/created) |

---

## Project Details

### opml-import
- **Branch:** `pipeline/opml-import`
- **PR:** https://github.com/dpaola2/show-notes/pull/1 (merged)
- **Milestones:** M0-M5 (5 implementation milestones)
- **Features:** OPML upload, parser, import service, favorites selection, ProcessEpisodeJob integration
- **Test coverage:** 60+ tests
- **Key commits:** `8e871ab` (M1), `0a439b0` (M2), `53e3d9d` (M3), `7e685eb` (M4), `94e7c3c` (M5)
- **Status:** Merged

### email-notifications
- **Branch:** `pipeline/email-notifications`
- **Milestones:** M0-M2 (2 implementation milestones)
- **Features:** SignupNotificationMailer, SessionsController integration
- **Test coverage:** 9 tests
- **Key commits:** `21c3104` (M1), `7db3ddf` (M2)
- **Status:** Implementation complete, ready for PR

### long-lived-authentication
- **Branch:** `pipeline/long-lived-authentication`
- **Milestones:** M0-M2 (2 implementation milestones)
- **Features:** 1-year session cookie, return-to URL
- **Test coverage:** 10 tests
- **Key commits:** `6441141` (M1), verification-only (M2)
- **Status:** Implementation complete, ready for PR

### onboarding
- **Branch:** `pipeline/onboarding`
- **Milestones:** M0-M6 (6 implementation milestones)
- **Features:** Email tracking, episode show page, AutoProcessEpisodeJob, digest redesign, engagement report
- **Test coverage:** 126 tests
- **Key commits:** `7c16ef6` (M1), `4453131` (M2), `c7fa7ff` (M3), verification-only (M4), `c52a4f8` (M5), `84ae1f6` (M6)
- **Status:** Implementation complete, ready for PR

### tweak-transcribe-ux
- **Branch:** `pipeline/tweak-transcribe-ux`
- **PR:** https://github.com/dpaola2/show-notes/pull/13 (open)
- **Milestones:** M0-M6 (6 implementation milestones)
- **Features:** Episode-level processing state, error handling fixes, Solid Queue concurrency throttling, stuck job detection, Inbox/Library retry UX
- **Test coverage:** 75 tests
- **Key commits:** `7bc178b` (M1), `ddeaf87` (M2), `2ccc842` (M3), `5049b27` (M4), `c906bd4` (M5), no commit (M6)
- **Lead time:** 13h 16m (PRD start → PR created)
- **Active time:** 34m (all stage durations)
- **Implementation time:** 42m 30s (M1 → M6)
- **Human review time:** 2h 27m (architecture approval)
- **Status:** PR open, awaiting QA

---

## Pipeline Throughput

| Metric | Count |
|--------|------:|
| **Projects completed** | 5 |
| **Projects merged** | 1 (opml-import) |
| **Projects ready for PR** | 3 (email-notifications, long-lived-authentication, onboarding) |
| **Projects in PR review** | 1 (tweak-transcribe-ux) |
| **Total milestones implemented** | 21 (excluding M0 discovery/alignment) |
| **Total test coverage** | 280+ tests |
| **Average project size** | 4.2 milestones, 18 files modified |

---

## Observations

### Pipeline Efficiency
- **Stage 0-4 duration:** ~35m for PRD → Test Generation (based on tweak-transcribe-ux)
- **Implementation speed:** 7m per milestone average (M1-M6)
- **Test generation:** 5m to generate 75 tests across 7 spec files
- **Human checkpoints:** Architecture review took 2h 27m; Gameplan review was pre-approved

### Project Patterns
- **Small projects (2 milestones):** email-notifications, long-lived-authentication — configuration/simple feature additions
- **Medium projects (5 milestones):** opml-import — new service + UI flow
- **Large projects (6 milestones):** onboarding, tweak-transcribe-ux — multi-component features with complex state management

### Quality Metrics
- **Test pass rate:** 100% (all projects have 0 failing tests in final state)
- **Known issues:** 1 pre-existing test issue in opml_import_service_spec.rb (queue isolation, passes in isolation)
- **Regressions:** 0 (no existing tests broken by pipeline implementations)

---

## Next Steps

1. **Complete PR review for tweak-transcribe-ux** — manual QA, merge
2. **Create PRs for ready projects:**
   - email-notifications
   - long-lived-authentication
   - onboarding
3. **Gather full metrics for earlier projects** — add timestamp frontmatter to PRD/discovery/architecture/gameplan/progress files for opml-import, email-notifications, long-lived-authentication, onboarding to enable comprehensive lead time analysis
