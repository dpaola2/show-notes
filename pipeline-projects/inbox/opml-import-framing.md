# OPML Import — Product Framing

> For Dave to turn into a PRD. This is the CEO's product perspective — what to build and why, not how.

---

## The One Goal

**Import today, wake up to a digest email tomorrow.**

That's the magic moment. Every decision in the flow should serve that outcome. If a new user imports their podcasts and doesn't get a digest the next morning, we've lost them.

---

## Who's Doing This

Someone we just Mom Tested who said "yeah I'd try that." They have Overcast or Apple Podcasts or Pocket Casts with 15-30+ subscriptions. They're willing to give us 5 minutes but not 30.

---

## Product Principles for This Feature

### 1. Hide "OPML" — lead with the app name

Nobody knows what OPML is except Hacker News readers. The UI should say **"Import from Overcast"** / **"Import from Apple Podcasts"** / etc., with app-specific export instructions. The file format is OPML under the hood, but the user action is "bring my podcasts over."

### 2. Solve the cold start problem

They import 25 feeds. Now what? Zero summaries. Empty inbox. Tomorrow's digest has nothing. They never come back.

We **must** get something processed before tomorrow morning's email.

### 3. Let them pick favorites — don't process everything

At ~$0.46/episode, auto-processing 25 episodes = ~$11.50 in AI costs for someone who might never return. But processing zero means no value.

**Recommendation:** After import, ask them to **pick 5-10 podcasts they care about most.** Process the latest episode from those. Cost: ~$2-5 we can absorb. Result: a real digest tomorrow with content from shows they actually care about.

The rest of their feeds start polling normally — new episodes appear in triage going forward.

### 4. Don't dump a backlog into the inbox

25 feeds x 10 recent episodes = 250 items in the inbox. That IS the overwhelm we're supposed to solve.

Import should **subscribe them to feeds going forward.** Only the latest episode from their selected favorites gets processed. Everything else starts fresh.

### 5. Show a cost estimate before processing

We already have cost estimation in the product. Use it here: _"We'll process 7 episodes from your favorite shows (~$3.22). Your first digest arrives tomorrow morning."_ Transparency builds trust, especially pre-pricing.

### 6. Keep scope razor-thin

This is a **one-time onboarding action for new users.** Don't build re-import, sync, merge, or duplicate detection. One upload, one flow, done.

---

## The Flow (CEO's Version)

1. **"Import your podcasts"** → pick your app → app-specific export instructions → upload file
2. **"We found 27 podcasts!"** → show the list with names and artwork
3. **"Pick the ones you care about most"** → select 5-10 favorites
4. **"Your first digest arrives tomorrow morning"** → show cost estimate → confirm
5. Processing happens in background
6. Next morning: digest email with real content from their shows

---

## Why This Matters Strategically

- **Snipd's onboarding email** lists "Import your subscriptions" as action #1. Every competitor treats OPML import as table stakes for power users. ([[insights]] — "Snipd's Onboarding Validates Our OPML Priority")
- **Phase 2 is blocked on this.** We can't onboard our Mom Test participants without it. No import = no real users = no usage data = stuck in Phase 1 forever.
- **The daily digest is the product** ([[insights]] — "The Daily Digest Is the Product"). Import is the fastest path from "new user" to "getting the digest."

---

## What I Don't Have an Opinion On (Dave's Call)

- Where in the UI this lives (onboarding flow? settings? both?)
- Technical approach to parsing OPML
- How to handle feeds we can't find / match
- Background job architecture for bulk processing
- Whether to show a progress indicator or just email when ready

---

## Cost Guardrails

| Scenario | Episodes Processed | AI Cost | Acceptable? |
|----------|-------------------|---------|-------------|
| Process all 25 feeds | 25 | ~$11.50 | No — too expensive for unvalidated user |
| Process top 10 picks | 10 | ~$4.60 | Yes — reasonable acquisition cost |
| Process top 5 picks | 5 | ~$2.30 | Yes — minimum viable magic moment |
| Process nothing | 0 | $0 | No — no value, user churns |

Sweet spot: **5-10 episodes from user-selected favorites.**

