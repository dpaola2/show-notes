# Phase 2 Onboarding — Product Framing (v2)

> What the product needs to do when we onboard Marcus and Ethan. Rewritten with behavioral data from Justin Jackson's screen recording and JTBD analysis. This is the CEO's product perspective — Dave turns it into technical tasks.

---

## What We Learned From Watching Real Behavior

Before framing the product, here's what we know from observing actual podcast triage (Justin Jackson screen recording + Mega Maker thread):

1. **Triage is a three-tier decision:** (a) Show identity — instant keep/skip for most shows, (b) Episode title — deciding factor for "occasional" tier shows, (c) Show notes — almost never consulted, didn't change outcomes when checked. See [[user-research/justin-jackson-triage.mp4]].

2. **Users feel abundance, not overwhelm.** Nobody is stressed. They've accepted missing things. "It's an ever flowing stream and I only ride on some of the boats." — Marcus.

3. **Time is the real constraint.** Ethan: "I'm at capacity in terms of time I have to listen." Not information quality. Not decision anxiety. Hours in the day.

4. **The "email inbox" metaphor is natural.** Justin: "Similar to how I process email inbox." Our inbox/triage flow mirrors behavior that already exists.

5. **Regret moments are real but rare.** Ethan: ~1/month, caught by accidental YT Shorts. Invisible misses are likely much higher.

---

## What We're Testing

**Job B: "Get value from your entire podcast feed — even the episodes you'll never have time to listen to."**

This is non-consumption. Nobody hires anything for this job today. The 35-40 episodes Marcus skips every week just disappear. Our test: if we surface the VALUE of those skipped episodes via AI summaries, does it change behavior?

See [[strategy/jtbd-analysis]] for the full Job A vs Job B analysis.

---

## The Magic Moment

Marcus opens his morning email. He sees summaries of 12 new episodes — including ones from shows in his "occasional" tier that he would have skipped based on title alone. One summary says something like: "This episode covers [topic Marcus cares about] with [guest he respects]." He thinks: "Oh — I would have skipped this. Actually, this is exactly what I needed."

That's the moment. Either:
- **He reads the summary and feels satisfied** → Job B works. He consumed the value without listening.
- **He reads the summary and downloads the episode** → Even stronger. We rescued an episode from the archive pile.
- **He deletes the email without reading** → Job B is dead.

---

## What Exists Today

| Feature | Status | Notes |
|---------|--------|-------|
| OPML import | **DONE** | Gate cleared |
| Inbox triage (skip/keep) | Built | Tests Job A, not Job B |
| AI processing pipeline | Built | AssemblyAI transcription + Claude summarization |
| Episode summaries | Built | Structured sections + quotes with timestamps |
| Daily digest email | **EXISTS but needs rescoping** | Current: 5 inbox titles + 2 library summaries. Needs: ALL episodes with summaries. |
| Auto-processing | **NOT BUILT** | Episodes only process when user adds to Library |
| Measurement/tracking | **NOT BUILT** | No open/click tracking |

---

## The Gap: Current Digest vs What Job B Needs

### Current digest (built)
```
📥 INBOX (5 new episodes)
  • Episode title — Show name
  • Episode title — Show name
  • (titles only, no summaries)
  +3 more → Open Inbox

📚 RECENTLY READY (2 episodes)
  • Full summary + quote (only for episodes user manually processed)
```

This is a **notification about the app**, not a product in itself. It tells you "stuff is waiting for you in the app." The value is in the web app, not in the email. It tests Job A.

### What the digest needs to become
```
Your podcasts this morning — 12 new episodes

[Show Name] — "Episode Title"
2-3 sentence AI summary surfacing what this episode is actually about.
The specific topics, guests, or arguments — not marketing copy.
→ Read full summary  |  → Listen

[Show Name] — "Episode Title"
2-3 sentence AI summary.
→ Read full summary  |  → Listen

... (all new episodes, not just 5)
```

This is a **podcast newsletter**. The value is IN the email. You open it, scan it, and either feel informed (Job B) or click through to read more / listen (bonus). The email is the product, the web app is the archive.

### The shift
- **Old digest:** "Here's what's waiting for you in the app" (notification)
- **New digest:** "Here's what your podcasts are about today" (newsletter)

---

## What Needs to Change

### 1. Auto-process new episodes
Currently episodes only get processed when the user adds them to Library. For Job B, new episodes need to be transcribed and summarized automatically.

**Cost reality:** Marcus gets ~50 episodes/week. At $0.46/episode = ~$23/week.

**My recommendation for the test:** Absorb the cost. 2-3 users for 1 week = $50-70 total. That's the cheapest user research we'll ever run. If Job B validates, we optimize costs later (transcript caching across users, lightweight summaries for low-priority shows, daily processing caps). If Job B dies, we spent $70 and got a clear answer.

**Alternative if cost is a concern:** Use Claude to generate a summary from just the RSS title + description (no transcription). ~$0.01/episode. Won't be as good, but it's 100x cheaper and still better than a raw title. Could be a useful "tier 2" summary approach even at scale.

### 2. Redesign the daily digest as a newsletter
The email needs to show ALL new episodes with summaries — not 5 titles and 2 summaries. This is a template redesign, not a new feature. The DigestMailer, job, scheduling, and user settings already exist.

**Design principles for the digest:**

- **Show everything, not a subset.** If Marcus has 12 new episodes today, show all 12. Don't truncate to 5 with a "+7 more" link. The whole point is that he sees summaries of episodes he'd skip.
- **Lead with the summary, not the title.** The title is what they already have in Pocket Casts. The summary is what we uniquely provide. It should be the most prominent element.
- **Keep it scannable.** These are people who triage 50 episodes in 4 minutes. The digest needs to be fast to scan. Short summaries (2-3 sentences), clear show/episode labels, visual separation between episodes.
- **Include a "listen" action.** If a summary makes someone want to hear the episode, there should be a direct path. Link to the episode in our app, or even a direct audio link.
- **Group by show or let it flow chronologically?** I don't have a strong opinion. Chronological is simpler. Grouping by show might match how users think (show-level decisions first). Dave's call.
- **Don't editorialize.** No "Top Pick!" or "You might like this." Just show the content and let the user decide. Our users are sophisticated — they don't want us telling them what to care about.

**What the digest does NOT need for Phase 2:**
- Beautiful HTML design (clean and readable is enough)
- Themed sections or editorial voice (post-validation polish)
- Per-user timezone or send time settings (default 7 AM Eastern is fine)
- Unsubscribe link compliance (handle when we have real customers, not test users)

### 3. Basic measurement
We need to know if people engage. At minimum:
- **Email opens** — did they even look at it?
- **Click tracking** on "Read full summary" links — which episodes did they click?
- **Bonus:** Can we tell which episodes they would have skipped vs kept? If they click through to summaries of shows they DON'T listen to, that's the signal.

---

## The Phase 2 Experience (End to End)

### Day 0: Onboarding
1. We send Marcus/Ethan a magic link with a note: "Trying something related to our podcast triage discussion — would love your honest take."
2. They import OPML → see their feeds imported
3. Episodes start auto-processing in the background
4. "Your first podcast briefing arrives tomorrow morning."

### Day 1: First Digest
5. Email arrives at 7 AM: "Your podcasts this morning — 14 new episodes"
6. Each episode: show name, title, 2-3 sentence AI summary, "Read more" / "Listen" links
7. Marcus scans it like he scans his Pocket Casts feed — but now he has summaries instead of just titles
8. **The test:** Does he read summaries of episodes from "occasional" tier shows? Does any summary flip a skip into a keep?

### Days 2-7: Observe
9. Does he open the email every day?
10. How long does he spend with it? (Can't measure directly, but can proxy via clicks)
11. Does he click through to any full summaries?
12. Does he discover anything he would have missed?
13. Does he mention it to anyone?

### Day 7+: Follow-up (Mom Test, behavior-focused)
14. "How did you use the morning email this week?"
15. "Did you find anything through a summary that you wouldn't have found through your normal triage?"
16. "Did you change anything about how you use Pocket Casts/Overcast?"
17. DON'T ask: "Did you like it?" or "Would you pay for this?"

---

## Where Our Value Lives (The Tier Model)

Based on Justin's behavior, every user's subscriptions fall into three tiers:

| Tier | User's current behavior | Our value |
|------|------------------------|-----------|
| **Always listen** | Never skip. Download every episode. | Low — they're already committed. Summary is bonus context, not decision-changing. |
| **Occasional** | Sometimes skip, sometimes listen. Decide by title. | **HIGH — this is our sweet spot.** A good summary surfaces episode-specific value that the title can't convey. Rescues episodes from the skip pile. |
| **Background noise** | Almost always skip. Subscribed but rarely engaged. | Medium — a summary might occasionally surface something surprising. But mostly they just don't care about this show. |

The digest is most valuable for the MIDDLE tier. The question is whether the middle tier is big enough to matter. Justin has "Mostly Technical, Hackers Inc" as always-listen and everything else as occasional. If "everything else" is 20+ shows, there are plenty of opportunities for summaries to add value.

---

## What I Don't Have an Opinion On (Dave's Call)

- Whether to auto-process everything or use a lightweight summary (RSS description + Claude) for cost control
- Technical approach to triggering auto-processing (on feed poll? separate job?)
- Digest template layout and styling
- Grouping episodes by show vs chronological
- Click tracking implementation (UTM params? redirect links? email service?)
- Whether the existing DigestMailer can be adapted or needs a rewrite

---

## Build Priority

1. **Auto-processing pipeline** — flip the switch so new episodes get processed without user action
2. **Digest email redesign** — all episodes, with summaries, newsletter format
3. **Basic click tracking** — know which summaries they engage with
4. **Onboard 2-3 test users** — Marcus and Ethan from Mega Maker

Items 1 and 2 can be built in parallel. Item 3 can be a fast follow. Item 4 happens when 1+2 are ready.

---

## Success Criteria

| Signal | What It Means |
|--------|--------------|
| 2/3 users open digest 5+ times in one week | The email is part of their morning routine |
| Users click through to summaries of episodes they didn't listen to | Job B is real — they're consuming content they'd have abandoned |
| A user goes back to listen to something discovered via summary | Strongest signal — we rescued an episode from the skip pile |
| A user forwards the digest or mentions it unprompted | Product-market fit territory |
| 0/3 open after day 3 | Job B is dead. Full stop. Reassess the thesis. |

---

## Cost Budget for Phase 2 Test

| Item | Cost | Notes |
|------|------|-------|
| Auto-processing for 3 users, 1 week | ~$50-70 | ~50 episodes/user/week × $0.46 × partial overlap |
| Transcript caching savings | -20-30% | Popular shows will overlap between users |
| **Total budget** | **~$50** | Cheapest user research we'll ever do |

If the test works, the next step is figuring out sustainable unit economics (transcript caching, lightweight summaries, processing caps). Don't optimize costs before validating the job.

---

## Links

- [[decisions/003-phase1-to-phase2]] — Why we're moving to Phase 2
- [[strategy/jtbd-analysis]] — Job A vs Job B framework
- [[products/opml-import-framing]] — OPML import goals (DONE)
- [[products/inspiration/substack-weekender]] — Digest design benchmark (for later polish)
- [[playbooks/problem-validation]] — How Phase 1 went
- [[user-research/justin-jackson-triage.mp4]] — Triage behavior screen recording
- [Mega Maker Slack thread](https://megamaker.slack.com/archives/CBPRUD35Y/p1770491471629239) — Where test users came from

---

*This doc is the product framing for Phase 2 onboarding. Dave turns it into technical tasks.*
