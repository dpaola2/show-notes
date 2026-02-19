---
pipeline_stage: 0
pipeline_stage_name: prd
pipeline_project: "latest-at-top-digest"
pipeline_started_at: "2026-02-19T07:24:06-0500"
pipeline_completed_at: "2026-02-19T07:25:37-0500"
---

# Latest-at-Top Digest Layout — PRD

|  |  |
| -- | -- |
| **Product** | Show Notes |
| **Version** | 1 |
| **Author** | Stage 0 (Pipeline) |
| **Date** | 2026-02-19 |
| **Status** | Approved |
| **Platforms** | Web only |
| **Level** | 1 |

---

## 1. Executive Summary

**What:** Redesign the daily digest email so the most recent episode is featured prominently at the top — with its full summary (all sections) and choice quotes displayed inline — followed by a compact list of up to 5 additional recent episodes in the current abbreviated format.

**Why:** The current digest treats all episodes equally with a 200-character preview. Surfacing the full summary and quotes for the latest episode makes the digest immediately valuable without requiring a click-through, increasing engagement and time-to-value for each email.

**Key Design Principles:**
- The digest should deliver value in the inbox — readers get the full summary without needing to open the app
- Older episodes remain discoverable but don't dominate the email

---

## 2. Goals & Success Metrics

### Goals
- Make the daily digest more useful by including full summary content inline
- Increase click-through rates on the featured episode's "Read in app" link
- Maintain discoverability of other recent episodes

### Success Metrics

| Metric | Target | Timeframe |
|--------|--------|-----------|
| Digest click-through rate (featured episode) | +20% vs. current | 30 days |
| Overall digest open rate | Maintain or improve | 30 days |
| Digest unsubscribe rate | No increase | 60 days |

`[NEEDS REVIEW]` — metrics are suggested defaults; adjust based on current baseline.

---

## 3. Feature Requirements

### Featured Episode (Top Section)

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| FE-001 | The most recently updated episode in the digest batch is displayed as the "featured" episode at the top of the email | Web | Must |
| FE-002 | The featured episode displays all summary sections (title + content for each section), not just the first 200 characters | Web | Must |
| FE-003 | The featured episode displays choice quotes from `summary.quotes`, visually styled as a blockquote or pull-quote | Web | Must |
| FE-004 | The featured episode includes a single "Read in app" link (tracked via existing EmailEvent system) | Web | Must |
| FE-005 | ~~The featured episode includes a "Listen" link~~ **Removed** — single "Read in app" link only (see ADR-001) | Web | ~~ |
| FE-006 | If the featured episode's summary is not yet ready, **skip it entirely** and feature the next most recent episode that has a summary. Episodes without summaries are excluded from the digest. (see ADR-001) | Web | Must |

### Recent Episodes (Bottom Section)

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| RE-001 | Below the featured episode, display up to 5 additional recent episodes in the current compact format (title + 200-char preview + links) | Web | Must |
| RE-002 | Recent episodes are ordered by recency (most recent first), excluding the featured episode | Web | Must |
| RE-003 | If fewer than 5 additional episodes exist, display however many are available | Web | Must |
| RE-004 | If only 1 episode total exists in the digest batch, show it as the featured episode with no "recent episodes" section | Web | Must |
| RE-005 | Only episodes with completed summaries are included in the bottom list. Episodes still processing are excluded entirely. (see ADR-001) | Web | Must |
| RE-006 | Always display a friendly "That's all for now" sign-off below the episode list (or below the featured episode if no bottom list) | Web | Must |

### Subject Line

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| SL-001 | Subject line format: `[Podcast Name]: Episode Title` for the featured episode | Web | Must |
| SL-002 | When additional episodes exist below, append `(+N more)` — e.g., `The Daily: Why the Economy Is Shifting (+4 more)` | Web | Must |

### Text Template

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| TXT-001 | The plain-text version of the digest mirrors the new layout: full summary + quotes for the featured episode, compact list for the rest | Web | Must |

---

## 4. Platform-Specific Requirements

### Web
- Both HTML and plain-text email templates must be updated
- HTML template should use email-safe styling (inline CSS, table layouts as needed)
- Quotes should be visually distinct — e.g., left border, italic, or background color
- The full summary sections should use clear headings for each section title
- No changes to the app's web UI — this is email-template-only

---

## 5. User Flows

### Flow 1: Digest with Multiple Episodes
**Persona:** Subscribed user with digest enabled
**Entry Point:** Email inbox (7 AM Eastern delivery)

1. User receives daily digest email
2. Email opens with featured episode: full summary sections displayed inline, followed by choice quotes
3. User reads the summary directly in the email
4. User optionally clicks "Read in app" to view the episode page
5. User scrolls down to see up to 5 more recent episodes in compact format
6. User clicks any episode link to open in the app
7. **Success:** User engages with content without needing to leave their email client for the featured episode
8. **Edge case:** Episodes without completed summaries are excluded entirely from the digest

### Flow 2: Digest with Single Episode
**Persona:** Subscribed user with one new episode
**Entry Point:** Email inbox

1. User receives digest with subject "[Podcast Name]: Episode Title"
2. Email shows the single episode as the featured episode with full summary and quotes
3. No "recent episodes" section appears
4. **Success:** User gets full value from the single episode

---

## 6. UI Mockups / Wireframes

### Digest Email — New Layout

```
┌─────────────────────────────────────────┐
│  Your library                           │
│  Wednesday, Feb 19 — 4 episodes ready   │
├─────────────────────────────────────────┤
│                                         │
│  PODCAST NAME                           │
│  ─────────────────────────────────────  │
│  Episode Title                          │
│                                         │
│  ## Key Takeaways                       │
│  Full content of the first summary      │
│  section, no truncation...              │
│                                         │
│  ## Discussion Points                   │
│  Full content of the second summary     │
│  section as well...                     │
│                                         │
│  ┃ "This is a choice quote from the     │
│  ┃  episode that stood out."            │
│  ┃                                      │
│  ┃ "Another notable quote pulled from   │
│  ┃  the transcript."                    │
│                                         │
│  [Read in app]  [Listen]                │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  LATEST EPISODES                        │
│  ─────────────────────────────────────  │
│                                         │
│  PODCAST B                              │
│  Episode Two Title                      │
│  First 200 chars of summary preview...  │
│  [Read full summary] [Listen]           │
│                                         │
│  PODCAST C                              │
│  Episode Three Title                    │
│  First 200 chars of summary preview...  │
│  [Read full summary] [Listen]           │
│                                         │
│  ... (up to 5 compact entries)          │
│                                         │
├─────────────────────────────────────────┤
│  [Open Show Notes]                      │
│  Manage preferences                     │
└─────────────────────────────────────────┘
```

---

## 7. Backwards Compatibility

N/A — no API or client-facing changes. This modifies email templates only.

---

## 8. Edge Cases & Business Rules

| Scenario | Expected Behavior | Platform |
|----------|-------------------|----------|
| Only 1 episode in digest batch | Show as featured episode, no "recent episodes" section | Web |
| Featured episode has no summary (still processing) | Skip it — feature the next most recent episode with a completed summary. If no episodes have summaries, do not send the digest. | Web |
| Featured episode has summary but no quotes | Show full summary sections, omit quotes block entirely | Web |
| Featured episode has empty quotes array `[]` | Same as no quotes — omit quotes block | Web |
| More than 6 total episodes in batch | Feature the most recent; show next 5 in compact list; remaining episodes are omitted from the digest | Web |
| All episodes lack summaries | Do not send the digest (return NullMail) — no value to deliver without summaries | Web |
| `[INFERRED]` Summary section has very long content (>2000 words) | Display in full — no truncation for the featured episode | Web |
| `[INFERRED]` Quotes contain special characters or markdown | Render as plain text in email (strip markdown if any) | Web |

---

## 9. Export Requirements

N/A — no export functionality involved.

---

## 10. Out of Scope

- Changing the digest delivery schedule or frequency
- Adding user preferences for which episode to feature
- Modifying the episode page in the web app
- Changing the email tracking system
- Adding new email event types beyond existing open/click
- `[DEFINE — any other features explicitly excluded?]`

---

## 11. Open Questions

| # | Question | Status | Decision | Blocking? |
|---|----------|--------|----------|-----------|
| 1 | Should "most recent" be determined by `published_at` or by `user_episodes.updated_at` (when it entered the library)? | Open | — | No |
| 2 | When there are >6 episodes, should the email mention "and X more in your library" at the bottom? | Open | — | No |
| 3 | How should quotes be visually styled — left border, italics, background color, or quotation marks? | Open | — | No |
| 4 | Should summary section headings (e.g., "Key Takeaways") be displayed, or just the content? | Open | — | No |

> **No blocking questions. Decisions from interview session captured in ADR-001.**

---

## 12. Release Plan

### Phases

| Phase | What Ships | Flag | Audience |
|-------|-----------|------|----------|
| Phase 1 | Updated digest templates (HTML + text) with featured episode layout | N/A | All digest-enabled users |

### Feature Flag Strategy
- No feature flag needed — this is a template change with no behavioral risk. The digest already has a per-user `digest_enabled` toggle.
- Rollback: revert the template commit.

---

## 13. Assumptions

- The `summary.quotes` field is reliably populated for processed episodes (may be empty array but not nil)
- Summary sections are already well-structured with `title` and `content` keys
- The existing EmailEvent tracking system does not need changes — the same "summary" and "listen" link types apply
- Email clients will render the full summary content acceptably (no major layout issues with longer emails)
- The DigestMailer's data-fetching logic already provides all necessary data (summary sections + quotes are eager-loaded via `includes(:summary)`)

---

## Appendix: Linked Documents

| Document | Link |
|----------|------|
| Source Notes | `docs/projects/inbox/latest-at-top-digest.md` |
| DigestMailer | `app/mailers/digest_mailer.rb` |
| Digest HTML Template | `app/views/digest_mailer/daily_digest.html.erb` |
| Digest Text Template | `app/views/digest_mailer/daily_digest.text.erb` |
| Summary Model | `app/models/summary.rb` |
