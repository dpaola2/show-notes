---
type: product-framing
tags: [product, distribution, growth, sharing, status/inbox]
created: 2026-02-18
---

# Shareable Episode Cards — Product Framing

> Auto-generate social media images from episode summaries. Public episode pages anyone can read without logging in. A share button that turns every summary into a distribution event.

---

## Why

Dave's first instinct with the summaries was to screenshot and share. That impulse is the growth loop — but screenshots are lossy: no link, no CTA, no branding, no click-through. Purpose-built shareable cards close the loop.

The funnel: user reads summary → taps "Share" → selects a quote → gets a branded card image + link → posts to Twitter/LinkedIn/iMessage → follower sees card → clicks → reads full synopsis on a public page → "Want this for YOUR podcasts?" → signs up.

This is the zero-cost distribution channel identified in earlier sessions. The missing piece is the mechanism.

**Substack's model:** When you share a Substack post, it auto-generates OG images, shared posts are publicly readable, and the reading experience IS the conversion experience. We should steal this playbook.

---

## What to Build

### 1. Public episode pages

**The critical prerequisite.** Episode synopsis pages must be readable without logging in. A shared link that hits a login wall is a dead end.

Today's episode pages likely require authentication. The change:

- Episode **synopsis** (sections + quotes) = public
- Episode **management actions** (library, triage, audio playback) = authenticated
- The public view is the reading experience + a CTA. The authenticated view is the full product.

Route structure suggestion:
- `/episodes/:id` — public synopsis view (anyone can read)
- Dashboard/library views — authenticated (existing behavior)

The public page needs:
- Episode title, podcast name, podcast artwork
- Full AI summary (sections + quotes)
- Prominent CTA: "Get summaries for your podcasts" → signup flow
- OG meta tags for rich link previews (title, description, image)
- Clean, readable design — this IS the first impression for potential users

### 2. Auto-generated OG images

When an episode is summarized, auto-generate an Open Graph image. This is what shows up when someone pastes the link into Twitter, LinkedIn, iMessage, Slack, etc.

**The image should include:**
- Podcast artwork (already stored — pulled from RSS feed)
- Episode title
- A compelling quote or one-line summary
- Show Notes branding (small, tasteful)

**Generation approach — builder decides:**

- **Option A: HTML/CSS → image via a rendering service.** Build an HTML template, render to PNG via Puppeteer, Imgproxy, or a screenshot API. Most flexible, easiest to iterate on design.
- **Option B: Ruby image generation (MiniMagick/ImageMagick).** Compose images programmatically. No browser dependency. Less design flexibility.
- **Option C: Third-party OG image service** (e.g., Vercel OG, Cloudinary). Fastest to ship, introduces a dependency.

The OG image gets stored (S3 or local) and served via the `og:image` meta tag on the public episode page.

### 3. Share button with quote selection

On the episode page (both public and authenticated views), add a "Share" button that:

1. **Default share:** Copies the episode URL + generates a generic card (episode title + podcast art)
2. **Quote share (stretch):** User highlights or selects a specific quote from the summary → generates a card with that quote featured → copies URL with quote anchor

The quote share is the Substack-style "highlight and share" pattern. It's the premium version — the default share is the MVP.

**Share targets to support:**
- Copy link (universal — works everywhere)
- Twitter/X (pre-filled tweet with quote + link)
- LinkedIn (pre-filled post)
- Web Share API (on mobile — native share sheet)

### 4. Share tracking (lightweight)

Track shares to understand which episodes/quotes get shared and whether shares convert to signups.

- Add a `shared` event to the existing click tracking infrastructure (`EmailEvent` or similar)
- UTM parameters on shared links: `?utm_source=share&utm_medium=social&utm_content=episode_123`
- Track: shares initiated, link clicks from shares, signups from shared links

---

## What NOT to Build (Yet)

- **Custom image editor.** Users don't need to customize fonts, colors, or layouts. Auto-generated is fine. Polish the template, not the tooling.
- **Instagram/TikTok format images.** Start with the standard OG card (1200x630). Vertical formats for Stories can come later if sharing takes off.
- **Embeddable widgets.** A "embed this summary on your blog" widget is interesting but premature.
- **Social media posting integration.** Don't post on the user's behalf. Give them the image + link and let them post. Removes OAuth complexity entirely.

---

## Design Principles

1. **The public page should feel like content, not a product pitch.** The synopsis should be genuinely useful to the reader. The CTA is present but not aggressive — like how Substack's free posts work.

2. **The card should be visually distinctive.** When someone scrolls Twitter and sees a Show Notes card, it should be recognizable. Consistent template, consistent branding, high quality.

3. **Sharing should feel like curation, not promotion.** The user is sharing because "I found this interesting," not because they're marketing your product. The card should emphasize the content (quote, episode, podcast) with Show Notes branding as a subtle attribution.

4. **Every shared link is a landing page.** The public episode page isn't just "a page that happens to be public." It's a conversion funnel entry point. Design it that way.

---

## Open Questions for the Builder

1. **Are episode pages currently behind auth?** If so, what's the simplest way to make a public read-only view? A separate controller action? A `before_action` skip for the show action?

2. **Where to store generated images?** Active Storage + S3? Local disk? Generated on-the-fly with caching? Tradeoff is storage cost vs. generation latency.

3. **When to generate the OG image?** Options: (a) when the summary is created (proactive), (b) when the public page is first requested (lazy), (c) when the user clicks "Share" (on-demand). Proactive is simplest for OG tags since social platforms fetch images at share time.

4. **What quote/excerpt to feature on the auto-generated card?** Options: (a) first quote from the quotes array, (b) first sentence of the first section, (c) a new "highlight" field in the summary prompt that asks Claude to pick the most shareable excerpt. Option (c) is probably worth it — Claude knows what's compelling.

5. **How to handle podcast artwork quality?** RSS feed artwork varies wildly in resolution and aspect ratio. The OG image template needs to handle everything from 100x100 favicons to 3000x3000 cover art.

---

## Success Criteria

- Episode pages are publicly accessible via a stable URL
- Pasting an episode URL into Twitter/Slack/iMessage shows a rich card with artwork and quote
- Authenticated users can share an episode with one tap
- At least one shared link results in a new signup (first evidence the growth loop works)

---

## Links

- `assistant/05-projects/show-notes/insights/shareable-episode-cards.md` — Insight note with Substack analysis
- `assistant/05-projects/show-notes/insights/summaries-social-objects.md` — Original insight: share impulse
- `assistant/05-projects/show-notes/insights/do-my-podcast-viral.md` — "Do my podcast" viral mechanic
- `assistant/05-projects/show-notes/strategy/go-to-market.md` — Distribution strategy
- `app/models/summary.rb` — Summary model (sections + quotes to pull from)
- Existing click tracking infrastructure (`EmailEvent`) for share tracking

---

*This is a framing doc, not a spec. The builder decides how.*
