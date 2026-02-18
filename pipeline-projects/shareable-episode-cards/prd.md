---
pipeline_stage: 0
pipeline_stage_name: prd
pipeline_project: "shareable-episode-cards"
pipeline_started_at: "2026-02-18T08:19:47-0500"
pipeline_completed_at: "2026-02-18T08:22:11-0500"
---

# Shareable Episode Cards — PRD

|  |  |
| -- | -- |
| **Product** | Show Notes |
| **Version** | 1 |
| **Author** | Stage 0 (Pipeline) |
| **Date** | 2026-02-18 |
| **Status** | Draft — Review Required |
| **Platforms** | Web only |
| **Level** | 3 [CONFIRM — significant new capability: public pages + image generation + share UI + tracking. Multiple milestones likely.] |

---

## 1. Executive Summary

**What:** Auto-generate branded Open Graph images from episode summaries, make episode pages publicly accessible without authentication, and add share functionality that turns every summary into a distribution event with tracking.

**Why:** Users' first instinct with summaries is to screenshot and share — but screenshots are lossy (no link, no CTA, no branding, no click-through). Purpose-built shareable cards close the growth loop: user shares → follower sees branded card → clicks through to public synopsis → discovers Show Notes → signs up. This is the zero-cost distribution channel. The missing piece is the mechanism.

**Key Design Principles:**
- The public page should feel like content, not a product pitch — the synopsis should be genuinely useful to the reader
- The card should be visually distinctive and recognizable in a social feed — consistent template, consistent branding
- Sharing should feel like curation, not promotion — emphasize the content with Show Notes branding as subtle attribution
- Every shared link is a landing page — the public episode page is a conversion funnel entry point

---

## 2. Goals & Success Metrics

### Goals
- Enable organic, zero-cost distribution of episode summaries via social sharing
- Make episode synopsis pages publicly accessible as standalone reading experiences
- Auto-generate branded OG images so shared links render rich previews everywhere
- Close the growth loop: share → read → sign up

### Success Metrics

| Metric | Target | Timeframe |
|--------|--------|-----------|
| Episode pages publicly accessible with OG images | 100% of summarized episodes | At launch |
| Share button usage (shares initiated per week) | 10+ [NEEDS REVIEW] | 30 days |
| Click-throughs from shared links | 50+ [NEEDS REVIEW] | 60 days |
| Signups attributed to shared links | 1+ (first evidence the growth loop works) | 90 days |

---

## 3. Feature Requirements

### Public Episode Pages

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| PUB-001 | Episode synopsis pages (sections + quotes) must be accessible without authentication | Web | Must |
| PUB-002 | Public page displays episode title, podcast name, and podcast artwork | Web | Must |
| PUB-003 | Public page displays the full AI summary (all sections and quotes) | Web | Must |
| PUB-004 | Public page includes a prominent CTA: "Get summaries for your podcasts" linking to the signup flow | Web | Must |
| PUB-005 | Public page includes OG meta tags (og:title, og:description, og:image, og:url) for rich link previews | Web | Must |
| PUB-006 | Public page has a clean, readable design appropriate as a first impression for potential users | Web | Must |
| PUB-007 | Management actions (library, triage, audio playback) remain authenticated-only | Web | Must |
| PUB-008 | Public page uses a stable, permanent URL (e.g., `/episodes/:id`) | Web | Must |

### OG Image Generation

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| OGI-001 | An Open Graph image (1200x630) is auto-generated for each summarized episode | Web | Must |
| OGI-002 | The OG image includes the podcast artwork | Web | Must |
| OGI-003 | The OG image includes the episode title | Web | Must |
| OGI-004 | The OG image includes a compelling quote or one-line summary excerpt | Web | Must |
| OGI-005 | The OG image includes Show Notes branding (small, tasteful) | Web | Must |
| OGI-006 | Generated images are stored persistently (Active Storage or equivalent) and served via the og:image meta tag | Web | Must |
| OGI-007 | Image generation handles variable podcast artwork quality (100x100 to 3000x3000) gracefully | Web | Must |
| OGI-008 | Image generation is triggered when a summary is created (proactive generation) | Web | Should |

### Share Functionality

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| SHR-001 | A "Share" button is present on the episode page (both public and authenticated views) | Web | Must |
| SHR-002 | Default share: copies the episode URL to clipboard | Web | Must |
| SHR-003 | Twitter/X share: opens pre-filled tweet with episode title + link | Web | Must |
| SHR-004 | LinkedIn share: opens pre-filled post with episode link | Web | Should |
| SHR-005 | Web Share API: on mobile, triggers native share sheet | Web | Should |
| SHR-006 | Quote share: user selects a specific quote from the summary, generates a card featuring that quote, copies URL with quote anchor | Web | Nice |

### Share Tracking

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| TRK-001 | Shared links include UTM parameters (utm_source=share, utm_medium=social, utm_content=episode_{id}) | Web | Must |
| TRK-002 | Track "share initiated" events (which episode, which share target) | Web | Must |
| TRK-003 | Track link clicks from shared links (landing on public page via UTM params) | Web | Should |
| TRK-004 | Track signups attributed to shared links (UTM source persisted through signup flow) | Web | Should |

---

## 4. Platform-Specific Requirements

### Web (Rails)
- Public episode pages served by the Rails app, no separate frontend needed
- OG image generation runs as a background job (Solid Queue) to avoid blocking request cycle
- Share button uses Stimulus controller for clipboard copy and share target handling
- OG images stored via Active Storage (or equivalent — architecture decision)
- Public pages should be cacheable and performant since they may receive traffic spikes from viral shares
- Tailwind CSS for public page styling, consistent with existing app design system

---

## 5. User Flows

### Flow 1: Organic Sharing (Authenticated User)
**Persona:** Existing Show Notes user
**Entry Point:** Episode page after reading a summary

1. User reads an episode summary on their dashboard
2. User clicks the "Share" button on the episode
3. Share popover/menu appears with options: Copy Link, Twitter/X, LinkedIn, (mobile: native share)
4. User selects "Twitter/X"
5. New tab opens with pre-filled tweet containing episode title and link (with UTM params)
6. User posts the tweet
7. **Success:** Tweet contains a rich card preview with podcast artwork, episode title, and quote
8. **Error:** If OG image hasn't been generated yet, the link still works but shows a generic preview (fallback to text-only OG tags)

### Flow 2: Link Click-Through (New Visitor)
**Persona:** Someone who sees a shared link on social media
**Entry Point:** Clicks shared link in Twitter/LinkedIn/iMessage

1. Visitor clicks the shared episode link
2. Browser loads the public episode page (no login required)
3. Visitor reads the full AI-generated summary (sections + quotes)
4. Visitor sees the CTA: "Get summaries for your podcasts"
5. Visitor clicks the CTA
6. **Success:** Visitor lands on the signup page (UTM params carry through for attribution)
7. **Error:** If episode doesn't exist or summary isn't ready, show a friendly 404

### Flow 3: Quote Share (Stretch Goal)
**Persona:** Existing Show Notes user who found a specific quote compelling
**Entry Point:** Episode page, reading a specific quote

1. User highlights or selects a quote from the summary
2. A "Share this quote" action appears
3. User clicks it — a card is generated featuring that specific quote
4. Share options appear (same as Flow 1)
5. **Success:** The shared link anchors to the specific quote on the public page
6. **Error:** If quote text can't be matched on the public page, link goes to the top of the summary

---

## 6. UI Mockups / Wireframes

### Public Episode Page
```
┌─────────────────────────────────────────────────────┐
│  [Podcast Artwork]  Episode Title                   │
│                     Podcast Name                    │
│                     Published: Jan 15, 2026         │
│                                        [Share ▾]    │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ## Key Takeaways                                   │
│  - Bullet point summary 1                           │
│  - Bullet point summary 2                           │
│                                                     │
│  ## Notable Quotes                                  │
│  > "Quoted text from the episode..."                │
│  > "Another compelling quote..."                    │
│                                                     │
│  ## Summary                                         │
│  Full paragraph summary text here...                │
│                                                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │  🎧 Get summaries for YOUR podcasts           │  │
│  │  Show Notes creates AI summaries of any       │  │
│  │  podcast episode. Try it free →                │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  Show Notes                                         │
└─────────────────────────────────────────────────────┘
```

### Share Popover
```
┌──────────────────────┐
│  Share this episode   │
├──────────────────────┤
│  📋 Copy Link        │
│  🐦 Twitter/X        │
│  💼 LinkedIn         │
│  📤 More... (mobile) │
└──────────────────────┘
```

### OG Image Card (1200x630)
```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  ┌────────┐                                         │
│  │Podcast │  Episode Title (large, bold)            │
│  │Artwork │  Podcast Name (smaller)                 │
│  │        │                                         │
│  └────────┘  ─────────────────────────              │
│                                                     │
│  "A compelling quote from the episode               │
│   that makes people want to click..."               │
│                                                     │
│                              Show Notes ♪           │
└─────────────────────────────────────────────────────┘
```

---

## 7. Backwards Compatibility

N/A — no backwards compatibility concerns for this project. Show Notes is a single-platform web app with no old client versions to support.

---

## 8. Edge Cases & Business Rules

| Scenario | Expected Behavior | Platform |
|----------|-------------------|----------|
| Episode has no summary yet | Public page shows "Summary not yet available" with basic episode metadata. No OG image generated. Share button still works (shares link, generic preview). | Web |
| Episode has summary but OG image generation failed | Public page still works. OG tags fall back to text-only (title + description, no og:image). | Web |
| Podcast has no artwork (missing from RSS feed) | OG image uses a default/placeholder artwork. Public page shows a generic podcast icon. | Web |
| Podcast artwork is very low resolution (< 200px) | OG image template scales artwork gracefully or uses placeholder if quality is unusable. | Web |
| Very long episode title (100+ characters) | OG image and public page truncate with ellipsis. OG title meta tag uses truncated version. | Web |
| Very long quote selected for OG image | Quote text is truncated with ellipsis on the OG image to fit the template. | Web |
| Episode is deleted after being shared | Shared links return a friendly 404 ("This episode is no longer available"). [INFERRED] | Web |
| User's account is deactivated | Public episode pages created by that user are still accessible (content is public). [INFERRED] | Web |
| Multiple summaries regenerated for same episode | OG image is regenerated with the latest summary content. Old image is replaced. [INFERRED] | Web |
| Concurrent share clicks (double-tap) | Only one share action is triggered (debounce on the share button). [INFERRED] | Web |
| Social platform caches old OG image after regeneration | No solution in-app — social platforms cache aggressively. Document that cache invalidation requires platform-specific tools (Twitter Card Validator, LinkedIn Post Inspector). [INFERRED] | Web |
| Episode page accessed by search engine crawler | Page is crawlable and indexable (public pages should support SEO). [INFERRED] | Web |

---

## 9. Export Requirements

N/A — this feature does not involve reports, exports, or data output.

---

## 10. Out of Scope

- **Custom image editor** — Users don't need to customize fonts, colors, or layouts. Auto-generated is fine.
- **Instagram/TikTok format images** — Start with the standard OG card (1200x630). Vertical formats for Stories can come later if sharing takes off.
- **Embeddable widgets** — A "embed this summary on your blog" widget is interesting but premature.
- **Social media posting integration** — Don't post on the user's behalf. Give them the image + link and let them post. Removes OAuth complexity entirely.
- **Quote-specific OG image generation** — The quote share (SHR-006) is Nice priority. Even if implemented, generating a unique OG image per quote is out of scope for v1 — the shared link uses the default episode OG image.
- **Analytics dashboard for share metrics** — Track the events, but a dedicated dashboard to visualize share performance is out of scope.
- **RSS feed modification** — Public pages exist at their own URLs. No changes to podcast RSS feed handling.

---

## 11. Open Questions

| # | Question | Status | Decision | Blocking? |
|---|----------|--------|----------|-----------|
| 1 | Are episode pages currently behind authentication? What's the simplest way to create a public read-only view? | Open | [NEEDS INPUT — review current EpisodesController auth setup] | Yes |
| 2 | Which OG image generation approach? (a) HTML/CSS → image via rendering service (Puppeteer, screenshot API), (b) Ruby image generation (MiniMagick/ImageMagick), (c) Third-party OG service (Vercel OG, Cloudinary) | Open | [Architecture decision — to be resolved in Stage 2] | No |
| 3 | Where to store generated OG images? Active Storage + S3? Local disk? Generated on-the-fly with caching? | Open | [Architecture decision — to be resolved in Stage 2] | No |
| 4 | What quote/excerpt to feature on the auto-generated card? (a) First quote from the quotes array, (b) First sentence of the first section, (c) A new "highlight" field in the summary prompt asking Claude to pick the most shareable excerpt | Open | [NEEDS INPUT — option (c) is recommended in framing doc but requires summary model/prompt changes] | No |
| 5 | How to handle podcast artwork quality variation? (100x100 to 3000x3000, variable aspect ratios from RSS feeds) | Open | [Architecture decision — to be resolved in Stage 2] | No |
| 6 | Should public pages be indexable by search engines (SEO)? If yes, do we need a sitemap? | Open | [NEEDS INPUT — SEO could drive organic traffic but may not be a v1 priority] | No |
| 7 | What does the signup flow look like when a visitor clicks the CTA? Is there an existing signup page, or does one need to be created/enhanced for this context? | Open | [NEEDS INPUT — review current signup flow] | Yes |

> **Blocking questions remain — resolve before pipeline intake.**

---

## 12. Release Plan

### Phases

| Phase | What Ships | Flag | Audience |
|-------|-----------|------|----------|
| Phase 1 | Public episode pages + OG images + basic share (copy link, Twitter/X) | `shareable_episode_cards` | All users (public pages are publicly accessible by nature) |
| Phase 2 | LinkedIn share + Web Share API + share tracking + CTA optimization | — | All users |

### Feature Flag Strategy
- Flag name: `shareable_episode_cards`
- Rollout: Global (feature flag controls whether share UI is shown to authenticated users; public pages are always-on once deployed)
- Default: Off
- Note: Public pages may need to be always-on (no flag) since the growth loop depends on links being publicly accessible. The flag may only control the share button visibility for authenticated users. [CONFIRM]

---

## 13. Assumptions

- Episode summaries (sections + quotes) already exist in the data model and are populated for most episodes
- Podcast artwork URLs from RSS feeds are stored and accessible for image generation
- The existing app has a signup flow that can accept UTM parameters for attribution
- Active Storage or an equivalent file storage mechanism is available for persisting generated images
- Background job infrastructure (Solid Queue) is operational and can handle image generation workload
- The app's current hosting (Kamal/Docker) can support an image generation dependency (e.g., ImageMagick, Puppeteer, or external API calls)

---

## Appendix: Linked Documents

| Document | Link |
|----------|------|
| Framing Doc (Inbox Source) | `~/projects/show-notes/pipeline-projects/inbox/shareable-episode-cards.md` |
| Insight: Shareable Episode Cards | `assistant/05-projects/show-notes/insights/shareable-episode-cards.md` |
| Insight: Summaries as Social Objects | `assistant/05-projects/show-notes/insights/summaries-social-objects.md` |
| Insight: "Do My Podcast" Viral Mechanic | `assistant/05-projects/show-notes/insights/do-my-podcast-viral.md` |
| Distribution Strategy | `assistant/05-projects/show-notes/strategy/go-to-market.md` |
| Summary Model | `app/models/summary.rb` |
