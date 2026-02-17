# Architecture Feedback: library-scoped-processing

1. **DetectStuckProcessing scope is unclear to me. Please make a concrete recommendation.**
I don’t fully understand whether episode-level stuck detection should remain. Please pick one approach and apply it consistently across PRD, discovery, and architecture docs. My preference is to choose a single source of truth and remove ambiguity.

2. **If something needs to change, it should change.**
Please update the docs directly wherever there are inconsistencies instead of leaving unresolved or contradictory guidance.

3. **Digest scope should include only the last 24 hours.**
Please explicitly define digest eligibility as episodes that became ready within the last 24 hours, and keep that rule consistent across PRD, discovery, architecture, and test expectations.

4. **Query duplication guidance is confusing. Please make a recommendation.**
Please recommend one clear approach for the 3 query locations (2 mailer paths + 1 job check): either extract a shared query helper/scope or intentionally keep them inline with a note on synchronization. I’d prefer a shared helper to reduce drift risk.

5. **Test cleanup plan needs a concrete recommendation.**
Please provide a complete test impact list and include all affected AutoProcess job specs (including state-tracking spec files), not just one file.

6. **Digest query SQL shape needs a clear recommendation.**
Please make an explicit recommendation for the query join/order strategy so ordering by podcast title is robust and not implicit. If ordering by `podcasts.title`, include an explicit podcast join in the canonical query.
