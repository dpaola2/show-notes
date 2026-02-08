# Phase 2 Onboarding — PRD

|  |  |
| -- | -- |
| **Product** | Show Notes |
| **Version** | 1 |
| **Author** | Stage 0 (Pipeline) |
| **Date** | 2026-02-07 |
| **Status** | Draft — Review Required |
| **Platforms** | Web only |
| **Level** | [CONFIRM — suggesting Level 2: web-only feature touching models, jobs, mailers, controllers, and views. No mobile/API clients.] |

---

## 1. Executive Summary

**What:** Enable automatic processing of all new podcast episodes and redesign the daily digest email from a notification ("stuff is waiting in the app") into a standalone newsletter ("here's what your podcasts are about today") with AI summaries for every episode. Add basic engagement tracking (opens, clicks) to measure whether users consume value directly from the email.

**Why:** Validate Job B — "Get value from your entire podcast feed, even the episodes you'll never have time to listen to." Phase 1 proved users triage by show identity and title. Phase 2 tests whether AI summaries of skipped episodes change behavior, surfacing value from the ~70% of episodes users currently ignore. This is the cheapest user research possible ($50-70 for 2-3 test users over one week).

**Key Design Principles:**
- The email IS the product — the value must be in the email itself, not behind a click to the web app
- Show everything, don't truncate — if a user has 12 new episodes, show all 12 with summaries
- Lead with the summary, not the title — the summary is our unique value; the title is what they already have
- Don't editorialize — no "Top Pick!" or recommendations; let users decide for themselves
- Keep it scannable — users triage 50 episodes in 4 minutes; the digest must match that speed

---

## 2. Goals & Success Metrics

### Goals
- Validate Job B: users consume value from podcast episodes they would have skipped
- Transform the daily digest from a notification into a standalone content product
- Enable automatic episode processing so summaries exist for all new episodes, not just user-curated ones
- Gather engagement data to measure whether the digest changes user behavior

### Success Metrics

| Metric | Target | Timeframe |
|--------|--------|-----------|
| Digest open rate | 2/3 test users open 5+ times in one week | 7 days |
| Summary click-through | Users click "Read full summary" on episodes they didn't listen to | 7 days |
| Episode rescue rate | At least 1 user discovers and listens to an episode via summary | 7 days |
| Abandon signal | If 0/3 users open after day 3, Job B is invalidated | 7 days |

---

## 3. Feature Requirements

### Auto-Processing Pipeline

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| AUTO-001 | New episodes from subscribed podcasts are automatically queued for AI processing (transcription + summarization) when discovered during feed polling | Web | Must |
| AUTO-002 | Auto-processing occurs without any user action — episodes do not need to be added to Library first | Web | Must |
| AUTO-003 | Auto-processing uses the existing AssemblyAI transcription + Claude summarization pipeline | Web | Must |
| AUTO-004 | Episodes that already have transcripts/summaries (e.g., from manual Library adds) are not re-processed | Web | Must |
| AUTO-005 | Auto-processing failures for individual episodes do not block processing of other episodes | Web | Must |
| AUTO-006 | No daily/weekly processing cap per user — absorb all costs for the Phase 2 test | Web | Should |
| AUTO-007 | When auto-processing is enabled, backfill ~10 most recent unprocessed episodes per podcast to seed initial digest content | Web | Must |

### Digest Email Redesign

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| DIG-001 | Daily digest email includes ALL new episodes since the last digest, not a truncated subset | Web | Must |
| DIG-002 | Each episode entry displays: show name, episode title, 2-3 sentence AI summary | Web | Must |
| DIG-003 | Each episode entry includes a "Read full summary" link to the episode's summary page in the web app | Web | Must |
| DIG-004 | Each episode entry includes a "Listen" link that opens the episode page in the web app (which has a play button) | Web | Must |
| DIG-005 | Summary text is the most visually prominent element per episode — more prominent than the title | Web | Must |
| DIG-006 | Episodes are visually separated with clear boundaries for fast scanning | Web | Must |
| DIG-007 | The email header shows the date and total episode count (e.g., "Your podcasts this morning — 14 new episodes") | Web | Must |
| DIG-008 | Episodes that have not finished processing yet are included with title only and a note like "Summary processing..." | Web | Should |
| DIG-009 | Episodes are grouped by show (matches triage mental model — users make show-level decisions first) | Web | Should |
| DIG-010 | The digest is clean and readable but does not require polished HTML design | Web | Must |
| DIG-011 | The existing DigestMailer, job, scheduling, and user email settings are reused/adapted rather than rewritten from scratch | Web | Must |
| DIG-012 | Digest sends at 7 AM Eastern (existing schedule) | Web | Must |
| DIG-013 | If a user has no new episodes since the last digest, no email is sent (skip empty digests) | Web | Should |

### Engagement Tracking

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| TRK-001 | Email open events are tracked (e.g., via tracking pixel) | Web | Must |
| TRK-002 | Click events on "Read full summary" links are tracked per episode via internal redirect links | Web | Must |
| TRK-003 | Click events on "Listen" links are tracked per episode via internal redirect links | Web | Should |
| TRK-004 | Tracking data is stored in the database and queryable (not just in an external service) | Web | Must |
| TRK-005 | A simple admin/developer view or rake task can report: opens per user per day, clicks per episode | Web | Should |
| TRK-006 | Tracking does not degrade email deliverability or rendering | Web | Must |

### Onboarding Flow

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| ONB-001 | After OPML import completes, auto-processing begins for all discovered episodes in the background | Web | Must |
| ONB-002 | User sees a message after OPML import indicating their first briefing arrives the next morning | Web | Should |
| ONB-003 | Magic link invitation flow is used to onboard test users (existing auth mechanism) | Web | Must |

---

## 4. Platform-Specific Requirements

### Web (Rails)
- Reuse existing DigestMailer infrastructure — adapt the template, don't rewrite the scheduling/delivery pipeline
- Background jobs via Solid Queue for auto-processing (already used for existing processing pipeline)
- Email delivery via Resend (production) / Letter Opener (development)
- Tracking pixel for opens; internal redirect links for click tracking — all data stored in our database
- Click tracking redirect links must gracefully degrade (if tracking fails, the user still reaches the destination)
- Tracking should work in all major email clients (Gmail, Apple Mail, Outlook)

### iOS
- No changes required — Level 2 project (web only)

### Android
- No changes required — Level 2 project (web only)

---

## 5. User Flows

### Flow 1: New User Onboarding
**Persona:** Marcus (podcast power user, ~50 episodes/week, invited via magic link)
**Entry Point:** Magic link email

1. Marcus receives an invitation email with a magic link and a personal note
2. He clicks the link and is authenticated into Show Notes
3. He imports his OPML file (existing flow — already built)
4. Show Notes discovers all subscribed feeds and begins importing episodes
5. Auto-processing kicks in: episodes are queued for transcription + summarization
6. Marcus sees a confirmation: "Your feeds are importing. Your first podcast briefing arrives tomorrow morning."
7. **Success:** Episodes process overnight; digest is ready by 7 AM the next day
8. **Error:** If OPML import fails, existing error handling applies. If processing fails for some episodes, they appear in the digest with title only.

### Flow 2: Daily Digest Consumption
**Persona:** Marcus (returning user, Day 1+)
**Entry Point:** Morning email (7 AM Eastern)

1. Marcus opens his email and sees "Your podcasts this morning — 14 new episodes"
2. He scans the digest — each episode has show name, title, and a 2-3 sentence summary
3. For his "always listen" shows, the summary provides bonus context (nice but not critical)
4. For his "occasional" tier shows, he reads a summary that surfaces a topic he cares about
5. He clicks "Read full summary" to see the full AI summary on the web app
6. For another episode, the summary is enough — he feels informed without listening or clicking
7. He finishes scanning in ~2 minutes and moves on with his morning
8. **Success:** Marcus consumed value from episodes he would have skipped based on title alone
9. **Error:** If no new episodes exist, no email is sent (DIG-013)

### Flow 3: Episode Rescue
**Persona:** Ethan (test user, "I'm at capacity in terms of time")
**Entry Point:** Digest email

1. Ethan scans the digest quickly
2. A summary from an "occasional" show catches his eye — it mentions a topic directly relevant to his work
3. He clicks "Listen" which opens the episode page in Show Notes with a play button
4. He listens directly or copies the link to his podcast player
5. **Success:** An episode that would have been invisible is now being listened to
6. **Error:** If the episode page fails to load, standard error handling applies

---

## 6. UI Mockups / Wireframes

### Daily Digest Email
```
Subject: Your podcasts this morning — 14 new episodes

─────────────────────────────────────────────
  YOUR PODCASTS THIS MORNING
  Friday, February 7 — 14 new episodes
─────────────────────────────────────────────

  ── MOSTLY TECHNICAL ──────────────────────

  "Episode Title Goes Here"

  This episode explores how remote teams are
  rethinking async communication, featuring a
  conversation with [Guest] about replacing
  Slack with structured weekly updates.

  → Read full summary  ·  → Listen

  "Another Episode From This Show"

  A breakdown of why TypeScript adoption
  plateaued in 2026 and what Deno is doing
  differently.

  → Read full summary  ·  → Listen

  ── BUILD YOUR SAAS ───────────────────────

  "Episode Title Here"

  A deep dive into the economics of podcast
  advertising in 2026, with data showing CPM
  rates have dropped 30% while listenership
  grew.

  → Read full summary  ·  → Listen

  ... (all shows, all episodes, no truncation)

─────────────────────────────────────────────
  Show Notes — Your daily podcast briefing
─────────────────────────────────────────────
```

---

## 7. Backwards Compatibility

N/A — no API or client-facing changes. This is a web-only feature that modifies an existing email digest and adds a background processing trigger. No external clients consume these interfaces.

### Migration Strategy
- The existing digest email template is replaced, not extended — the old "notification" format is superseded
- Users who had the old digest format will simply receive the new format going forward
- Existing unprocessed episodes are backfilled — cap at ~10 most recent per podcast to keep costs reasonable, then auto-process new arrivals going forward

---

## 8. Edge Cases & Business Rules

| Scenario | Expected Behavior | Platform |
|----------|-------------------|----------|
| User has 0 new episodes since last digest | No digest email is sent | Web |
| User has 50+ new episodes in one digest | All 50+ are included — no truncation. Email may be long. | Web |
| Episode processing fails (transcription error) | Episode appears in digest with title only, no summary. Note: "Summary unavailable" | Web |
| Episode is still processing at digest send time | Episode appears with title and "Summary processing..." note | Web |
| User imports OPML at 6:55 AM (5 min before digest) | First digest goes out next day — don't send a digest with 0 processed episodes | Web |
| [INFERRED] Multiple episodes from the same show in one digest | Each episode listed individually (not collapsed under show header), regardless of ordering strategy | Web |
| [INFERRED] User has no subscribed podcasts | No digest sent; user sees "Add podcasts to get your daily briefing" on dashboard | Web |
| [INFERRED] Episode audio URL is missing or invalid | "Listen" link still works — it opens the episode page in web app regardless | Web |
| [INFERRED] Tracking pixel blocked by email client | Open event is not recorded; clicks still trackable via redirect links | Web |
| [INFERRED] User clicks tracking link but service is temporarily down | User is redirected to destination regardless — tracking failure is silent, never blocks navigation | Web |
| [INFERRED] Very long episode summary (processing edge case) | Digest shows truncated 2-3 sentence version; "Read full summary" goes to complete version | Web |
| [INFERRED] Podcast feed returns duplicate episodes (duplicate GUIDs) | Existing dedup logic handles this — auto-processing inherits the same protection | Web |

---

## 9. Export Requirements

N/A — this feature does not produce exports (PDF, Excel, CSV).

---

## 10. Out of Scope

- Beautiful/polished HTML email design (clean and readable is sufficient for Phase 2)
- Themed sections or editorial voice in the digest
- Per-user timezone or send-time settings (7 AM Eastern for all users)
- Unsubscribe link compliance (address when real customers exist, not test users)
- Cost optimization (transcript caching across users, lightweight summaries, processing caps) — validate Job B first
- Per-show or per-tier customization (e.g., "only summarize my occasional tier")
- Episode recommendations or editorial curation ("Top Pick!", "You might like this")
- Full retroactive processing of all historical episodes (backfill is capped at ~10 most recent per podcast)
- A/B testing of digest formats
- Mobile app integration

---

## 11. Open Questions

| # | Question | Status | Decision | Blocking? |
|---|----------|--------|----------|-----------|
| 1 | Should auto-processing use full transcription ($0.46/ep) or lightweight RSS-based summaries ($0.01/ep) for the Phase 2 test? | Resolved | Full transcription — absorb cost (~$50-70 total) for the test | Yes |
| 2 | Should episodes be ordered chronologically or grouped by show in the digest? | Resolved | Grouped by show — matches triage mental model | No |
| 3 | Should there be a daily/weekly processing cap per user, or absorb all costs during the test? | Resolved | No cap — absorb all costs during the test | No |
| 4 | What click tracking implementation should be used — redirect links (internal), UTM params, or an email service provider feature? | Resolved | Internal redirect links — keeps tracking data in our database, no external dependency | No |
| 5 | Should existing unprocessed episodes be backfilled when auto-processing ships, or only process new arrivals? | Resolved | Backfill ~10 most recent per podcast, then auto-process new arrivals going forward | No |
| 6 | Can the existing DigestMailer be adapted in-place, or does the template change warrant a new mailer? | Resolved | Adapt existing DigestMailer in-place — replace the old format, don't keep the old version | No |
| 7 | How should "Listen" links work — direct audio URL from the RSS feed, or link to the episode page in the web app with a play button? | Resolved | Episode page in the web app with play button — keeps users in the product, easier to track | No |

> **Assessment:** All questions resolved. No blocking questions remain — this PRD is ready for pipeline intake (after human review).

---

## 12. Release Plan

### Phases

| Phase | What Ships | Flag | Audience |
|-------|-----------|------|----------|
| Phase 1 | Auto-processing + redesigned digest + basic tracking | N/A (single-user app, no feature flag needed) | 2-3 invited test users (Marcus, Ethan) |
| Phase 2 | Cost optimization + polish (if Job B validates) | N/A | Broader beta |

### Feature Flag Strategy
- Show Notes is a single-user app with invited test users — no feature flag infrastructure needed for Phase 2
- The feature ships directly; rollback is reverting the deploy

---

## 13. Assumptions

- The existing AssemblyAI transcription + Claude summarization pipeline works reliably at the scale of ~50 episodes/user/week
- Resend (email provider) supports tracking pixels and does not strip them
- Episode audio URLs are available and valid in RSS feed data
- 2-3 test users (Marcus, Ethan) are willing and available for a 1-week test
- $50-70 processing cost for the test period is approved
- 7 AM Eastern send time works for the initial test cohort
- The existing OPML import and feed polling infrastructure handles the additional volume of auto-processing
- Solid Queue can handle the burst of processing jobs when a new user imports 20+ podcast feeds

---

## Appendix: Linked Documents

| Document | Link |
|----------|------|
| Product Framing (Source) | `inbox/onboarding.md` |
| JTBD Analysis | `[[strategy/jtbd-analysis]]` |
| Phase 1 → Phase 2 Decision | `[[decisions/003-phase1-to-phase2]]` |
| Justin Jackson Triage Recording | `[[user-research/justin-jackson-triage.mp4]]` |
| Mega Maker Slack Thread | [Slack](https://megamaker.slack.com/archives/CBPRUD35Y/p1770491471629239) |
| Substack Weekender (Design Benchmark) | `[[products/inspiration/substack-weekender]]` |
| Problem Validation Playbook | `[[playbooks/problem-validation]]` |
