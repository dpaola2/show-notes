# ADR-001: Digest Redesign Decisions

| | |
|--|--|
| **Status** | Accepted |
| **Date** | 2026-02-19 |
| **Context** | Interview session to refine the latest-at-top digest PRD |

---

## Context

The original PRD was generated from a brief idea note. An interview session was conducted to clarify ambiguities and make key design decisions before moving to discovery and architecture.

## Decisions

### 1. Featured episode selection

**Decision:** The single most recent episode across all the user's subscriptions gets featured treatment. Not per-show — one episode total.

**Rationale:** Keeps the email focused and positions the digest as a content-forward newsletter rather than a dashboard notification.

### 2. Featured episode content

**Decision:** Mirror the full in-app summary view — all summary sections (title + content) and all quotes from `summary.quotes`.

**Rationale:** The digest should deliver value in the inbox without requiring a click-through.

### 3. Featured episode links

**Decision:** Single "Read in app" link only. No separate "Listen" link for the featured episode.

**Rationale:** The featured section already contains the full summary. The primary call-to-action is to drive the user into the app, not to a specific action.

### 4. Bottom episode list

**Decision:** Up to 5 additional episodes (excluding the featured), compact format matching today's layout. Both "Read full summary" and "Listen" links retained.

**Rationale:** These are discovery items — the user hasn't read them yet, so both actions (read summary, listen) are useful.

### 5. Exclude episodes without summaries

**Decision:** Episodes still processing (no completed summary) are excluded entirely from the digest. No "Summary processing..." indicators.

**Rationale:** The digest should only show content that delivers value. A "processing" placeholder wastes space and creates a poor impression. If no episodes have summaries, the digest is not sent.

### 6. Sign-off message

**Decision:** Always display a "That's all for now" message at the bottom of the email, regardless of episode count.

**Rationale:** Provides a friendly closure and signals the user has seen everything.

### 7. Subject line

**Decision:** Format as `[Podcast Name]: Episode Title` for the featured episode. When additional episodes exist, append `(+N more)`.

Examples:
- `The Daily: Why the Economy Is Shifting`
- `The Daily: Why the Economy Is Shifting (+4 more)`

**Rationale:** Positions the product as a podcast syndicator — users grow to see the digest as their primary podcast consumption platform, not just a summarization utility. Inspired by Substack's approach of using content titles as subject lines.

### 8. Single-episode edge case

**Decision:** If only one episode qualifies, show it as the featured episode with no bottom list. The "That's all for now" sign-off still appears.

## Consequences

- The `library_ready_since` scope may need adjustment to filter for episodes with completed summaries only
- The DigestMailer needs to separate the featured episode from the rest, rather than grouping all by show
- The subject line generation moves from a static template to dynamic content based on the featured episode
- Email tracking events may need a slight adjustment since the featured episode only has one link type ("summary" click event for "Read in app")
