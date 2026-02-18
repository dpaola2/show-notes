---
type: product-framing
tags: [product, pricing, status/active, priority/p0]
created: 2026-02-12
---

# Cost Guardrails — Product Framing

> The auto-processing pipeline has no cost awareness. One user importing a full podcast library burned $150 in transcription before anyone noticed. This must be solved before onboarding anyone.

---

## What Happened

Dave imported a large number of podcasts into his account. The feed poller runs every 10 minutes. Every poll triggers `AutoProcessEpisodeJob` for new episodes. With dozens of podcasts, that's a firehose of transcription requests — each at ~$0.46. Total cost: ~$150 before he caught it and turned off transcription manually.

## Why It Matters

This is what happens to every power user on Day 1. Marcus has 50 episodes/week. Steven Wu has a full podcast library. Anyone importing an OPML file with 30+ podcasts will trigger the same cost explosion — and they won't know to turn it off.

At $10/mo subscription, one uncontrolled import costs more than a year of that user's revenue.

---

## The Two Cost Phases

The key insight: **ongoing costs are fine. Import costs are the problem.**

| Phase | What Happens | Volume | Risk |
|-------|-------------|--------|------|
| **Import/backlog** | User adds podcasts, system processes existing episodes | Potentially hundreds of episodes in hours | Unbounded cost spike |
| **Ongoing/daily** | New episodes arrive via feed poll, get processed for digest | 2-10 episodes/day for a typical user | Predictable, manageable |

The daily drip at 5 eps/day = ~$2.30/day = ~$69/mo. Still over our $10 price, but transcript caching will bring this down at scale. The import spike is the acute problem — it's a one-time cost explosion that happens before the user has received any value.

---

## Principles

1. **The user should never have a surprise cost experience.** Even though they're not paying per-episode, we are. If the system is going to process 200 episodes, the user should know that and opt in.

2. **Don't punish engagement.** Credit-counting makes users anxious. The goal is guardrails they rarely feel, not a meter they watch.

3. **New episodes matter more than old ones.** The daily digest is the product. Processing today's episodes for tomorrow's email is the core loop. Backlog processing is a bonus, not the main event.

4. **Simple beats clever.** One cap is better than three tiers. A hard limit is better than a soft limit with exceptions.

---

## What to Build

### 1. Daily processing cap per account

Set a hard limit on how many episodes can be processed per day per account. Something like **20 episodes/day**.

- Most users get 2-10 new episodes/day — they'll never feel it
- A big OPML import gets throttled over multiple days instead of hitting all at once
- When the cap is reached, queue the rest for tomorrow
- Show the user something like: "12 episodes processed today. 34 more queued for tomorrow."

### 2. OPML import: latest only by default

When a user imports an OPML file with many podcasts:

- Process only the **most recent episode per podcast**
- Don't auto-process the entire backlog
- Older episodes are available to process on-demand (one tap) or drip in over subsequent days via the daily cap

This means: import 50 podcasts, get 50 summaries over the next 2-3 days (daily cap), not 500 summaries in 2 hours.

### 3. Admin-level cost visibility

Not user-facing, but we need it:

- Total transcription spend per day, per user
- Alert if any single account exceeds $X/day (maybe $10?)
- Ability to pause processing for a specific account

---

## What NOT to Build

- **Per-episode pricing or credits.** Kills engagement. Users should feel like it's unlimited.
- **Multiple subscription tiers.** One price, one experience. Caps exist for cost protection, not as a monetization lever.
- **User-visible cost information.** Users don't need to know what episodes cost us. They see "20 episodes/day" as a product constraint, not a cost constraint.

---

## Open Questions for the Builder

1. **What's the right daily cap number?** 20/day is a guess. Could look at actual episode arrival rates for a heavy subscriber to calibrate. The cap should be high enough that ongoing daily usage never hits it — only import spikes do.

2. **Should the cap be episodes processed or episodes transcribed?** If a transcript is already cached (another user processed the same episode), it costs us ~$0.10 instead of $0.46. Cached episodes could be "free" against the cap since they're cheap.

3. **What does the user see when they hit the cap?** Needs to feel like a feature ("we spread your imports over a few days for the best experience") not a limitation ("you've exceeded your daily limit").

4. **Does the existing `AutoProcessEpisodeJob` need to be restructured, or can the cap be a check at the front?** Simplest is probably a counter check before enqueuing.

---

## Success Criteria

- Dave can re-enable transcription and import his full podcast library without cost anxiety
- A new user importing 50+ podcasts via OPML gets a good first-day experience (some summaries immediately, rest over next few days) without generating an unbounded cost event
- Daily digest users processing 5-10 eps/day never know the cap exists

---

## Links

- [[../insights]] — "Unit Economics Crisis" section (2026-02-12)
- [[../strategy/pricing]] — Pricing strategy and unit economics
- [[../decisions/002-transcript-caching]] — Transcript caching reduces per-episode cost for popular shows
- [[../_state.md]] — Action item #4b

---

*This is a framing doc, not a spec. The builder decides how.*
