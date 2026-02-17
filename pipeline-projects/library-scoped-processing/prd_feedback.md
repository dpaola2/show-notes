# PRD Feedback: library-scoped-processing

## Key Issues

1. **Intake-ready claim conflicts with unresolved placeholders**
- `prd.md:148` includes `[NEEDS REVIEW]`
- `prd.md:150` includes `[INFERRED]`
- `prd.md:178` says "No blocking questions — this PRD is ready for pipeline intake"
- Why this is odd: the document still has unresolved markers while asserting readiness.
- Suggested fix: resolve/remove placeholders, or downgrade readiness language.

2. **Potentially blocking ambiguity is marked non-blocking**
- `prd.md:175` leaves open whether the digest window should use `user_episodes.updated_at` vs `digest_sent_at`.
- Why this matters: this choice controls duplicate/missed digest items and affects both DIG-001/DIG-002 behavior.
- Suggested fix: make this decision explicit in the PRD before implementation.

3. **"Recover" wording does not match current behavior**
- `prd.md:71` says `DetectStuckProcessingJob` should "detect and recover" stuck processing.
- Current code marks stuck records as `error`; it does not auto-retry or re-enqueue (`app/jobs/detect_stuck_processing_job.rb:7`, `app/jobs/detect_stuck_processing_job.rb:20`).
- Suggested fix: change wording to "detect and mark as error for manual retry" (or explicitly require auto-recovery if that is intended).

4. **Technical rationale about episode-level processing columns is inaccurate**
- `prd.md:78` says episode-level `processing_status` fields remain because they are "still used by `ProcessEpisodeJob` for shared transcript caching".
- Current `ProcessEpisodeJob` tracks status on `UserEpisode`, and uses transcript/summary presence for cache reuse, not episode processing columns (`app/jobs/process_episode_job.rb:16`, `app/jobs/process_episode_job.rb:24`, `app/jobs/process_episode_job.rb:39`).
- Suggested fix: reword to: keep episode-level fields for backward compatibility / legacy auto-processing records / stuck-detection coverage.

5. **Library-only principle conflicts with edge-case behavior**
- Principle says "only process what's in the library" (`prd.md:30`).
- Edge case says if user archives before completion, processing continues anyway (`prd.md:148`).
- Why this is inconsistent: user intent changed out of library, but processing still consumes API cost.
- Suggested fix: decide explicitly between:
  - A) continue processing once started (simpler, possibly wasteful), or
  - B) add a guard in `ProcessEpisodeJob` to skip if no longer in library.

6. **DIG-002 language is internally ambiguous**
- `prd.md:60` says "ready or recently became ready since the last digest".
- "Ready" alone could include old already-ready items forever; "recently became ready" implies a cutoff.
- Suggested fix: tighten wording to one rule (e.g., "library episodes with `processing_status=ready` and readiness timestamp > since").

## Minor Notes

1. **DIG-004 priority may be too low for stated goals**
- PRD sets DIG-004 as `Should` (`prd.md:62`), but flow and success framing imply "no content => no email" is core behavior (`prd.md:100`, `prd.md:146`).
- Suggested fix: consider upgrading DIG-004 to `Must` for consistency.

2. **Open question #3 appears out-of-scope for this PRD**
- `prd.md:176` asks about inbox status indicators, while section 6 says no UI changes (`prd.md:132`).
- Suggested fix: either explicitly mark as follow-up/out-of-scope, or remove from open questions.
