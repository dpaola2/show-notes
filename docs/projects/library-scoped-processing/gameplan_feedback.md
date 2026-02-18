# Gameplan Feedback: library-scoped-processing

## Findings

1. **High — Gameplan conflicts with PRD on stuck episode handling**
- Gameplan proposes removing episode-level stuck detection and handling only `UserEpisode` records: `gameplan.md:35`, `gameplan.md:61`, `gameplan.md:113`, `gameplan.md:122`, `gameplan.md:160`.
- PRD still states episode-level fields remain for `DetectStuckProcessingJob` coverage and expects old episode-level stuck records to be handled: `prd.md:78`, `prd.md:150`.
- **Why this matters:** Implementation and tests will diverge from PRD intent unless these docs are aligned.
- **Suggested change:** Update either PRD or gameplan so both describe the same `DetectStuckProcessingJob` scope.

2. **Medium — DIG-003 traceability is incomplete (subject line only)**
- Gameplan maps DIG-003 to subject-line updates only: `gameplan.md:84`, `gameplan.md:96`, `gameplan.md:270`.
- PRD DIG-003 requires subject line **and copy** to be library-centric: `prd.md:61`.
- **Why this matters:** Current plan can pass while still violating PRD wording.
- **Suggested change:** Add explicit acceptance criteria/tasks for digest template copy updates (HTML + text), or narrow DIG-003 wording in PRD.

3. **Medium — “No remaining references” done criteria is not realistically scoped**
- Done criteria requires zero `AutoProcessEpisodeJob` references in the entire codebase: `gameplan.md:161`, `gameplan.md:166`, `gameplan.md:247`.
- The gameplan document itself contains intentional references, so literal zero is not achievable.
- **Why this matters:** Creates an impossible completion condition.
- **Suggested change:** Scope this to runtime code and active tests (e.g., `app/`, `config/`, and spec files under test), not docs/history artifacts.

4. **Low — “old episode-level stuck records age out naturally” is ambiguous/non-testable**
- `gameplan.md:160` says old episode-level stuck records “age out naturally” after removing episode-level detection.
- **Why this matters:** Without explicit cleanup logic, this behavior is vague and hard to verify.
- **Suggested change:** Replace with a concrete statement (e.g., legacy episode-level stuck rows may remain; no new episode-level processing is enqueued).

## Overall

The gameplan is close, but it should be updated to remove PRD/gameplan contradictions and make completion criteria testable.
