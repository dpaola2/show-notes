# Show Notes v1.1 — Polish & Daily Digest

## Overview

Version 1.1 focuses on UI polish and a new daily digest email feature. These improvements make the app feel more professional on desktop and usable on mobile, while the digest helps users stay on top of their podcast queue without opening the app.

---

## Features

### 1. Button Cursor Fix

**Problem**: Clickable elements (buttons, links styled as buttons) show the default arrow cursor instead of the pointer (hand) cursor, making the UI feel unresponsive.

**Solution**: Add `cursor: pointer` to all interactive elements.

**Scope**:
- All `<button>` elements
- All `.btn` or button-styled elements
- Clickable cards/rows in inbox and library
- Any element with `onclick` or Turbo actions

**Implementation**:
```css
button, [role="button"], .btn, [data-action] {
  cursor: pointer;
}
```

**Acceptance Criteria**:
- [ ] All buttons show pointer cursor on hover
- [ ] Clickable list items show pointer cursor
- [ ] No regression on non-interactive elements

---

### 2. Responsive Mobile Web

**Problem**: The UI is designed for desktop and doesn't adapt well to mobile screen sizes. Elements overflow, text is too small, and touch targets are inadequate.

**Solution**: Make the existing UI responsive using Tailwind's responsive utilities.

**Key Areas**:

| Area | Desktop | Mobile |
|------|---------|--------|
| Navigation | Horizontal tabs/links | Bottom nav or hamburger menu |
| Inbox list | Multi-column with metadata | Single column, stacked metadata |
| Episode detail | Side-by-side summary/audio | Stacked, summary first |
| Buttons | Standard size | Larger touch targets (min 44px) |
| Typography | Current sizes | Slightly larger body text |
| Spacing | Current padding | More breathing room |

**Breakpoints** (Tailwind defaults):
- `sm`: 640px
- `md`: 768px
- `lg`: 1024px

**Priority Order**:
1. Inbox view (most used)
2. Library view
3. Episode detail view
4. Podcast browse/search
5. Settings

**Acceptance Criteria**:
- [ ] All views usable on 375px width (iPhone SE)
- [ ] Touch targets minimum 44x44px
- [ ] No horizontal scrolling
- [ ] Text readable without zooming
- [ ] Audio player controls accessible on mobile

---

### 3. Daily Digest Email

**Problem**: Users forget to check their inbox and miss new episodes. Opening the app daily feels like a chore.

**Solution**: Send a daily digest email every morning with:
1. New episodes in the inbox (to encourage triage)
2. Recently processed episodes with summaries (to deliver value without opening app)

**Email Content**:

```
Subject: Your Daily Podcast Digest — Jan 25

Good morning!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📥 INBOX (5 new episodes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• The Daily — "Headlines for January 25"
• Acquired — "NVIDIA Part III"
• Syntax — "Serverless Functions Deep Dive"
• [+2 more]

→ Open Inbox: https://listen.davepaola.com/inbox

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📚 RECENTLY READY (2 episodes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

THE DAILY — "Breaking News Analysis"
45 min • Ready yesterday

Sections:
1. Opening Headlines (0:00-5:30)
   Brief overview of top stories...
2. Deep Dive: Economic Policy (5:30-25:00)
   Detailed analysis of...
3. International Roundup (25:00-40:00)
   Coverage of events in...

Notable Quotes:
• "This is the most significant policy shift..." (12:34)
• "We haven't seen numbers like this since..." (28:45)

→ Read full summary: https://listen.davepaola.com/episodes/123

---

ACQUIRED — "NVIDIA Part III"
2h 15min • Ready 2 days ago

[Similar format...]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Manage digest settings: https://listen.davepaola.com/settings
```

**Configuration**:

| Setting | Default | Options |
|---------|---------|---------|
| Digest enabled | Yes | Yes/No |
| Send time | 7:00 AM | User's local time |
| Inbox limit | 5 episodes | 3, 5, 10, all |
| Library limit | 2 episodes | 1, 2, 3, 5 |
| Include summaries | Yes | Yes/No |
| Include quotes | Yes | Yes/No |

**Technical Implementation**:

1. **Scheduled Job**: `SendDailyDigestJob`
   - Runs via Solid Queue recurring task at 7:00 AM UTC (adjust per user timezone later)
   - Queries users with `digest_enabled: true`
   - Skips if no new inbox items AND no recent library items

2. **Mailer**: `DigestMailer#daily_digest`
   - Accepts user, inbox_episodes, library_episodes
   - Renders both HTML and plain text versions

3. **User Settings**:
   - Add `digest_enabled` boolean (default: true)
   - Add `digest_sent_at` timestamp (to track last send)
   - Future: `digest_time`, `digest_timezone` for customization

4. **Database Changes**:
   ```ruby
   add_column :users, :digest_enabled, :boolean, default: true
   add_column :users, :digest_sent_at, :datetime
   ```

**Acceptance Criteria**:
- [ ] Digest email sends daily at 7 AM UTC
- [ ] Email includes inbox count and episode titles
- [ ] Email includes recent library summaries with sections and quotes
- [ ] Email has working links to app
- [ ] Users can disable digest in settings
- [ ] No email sent if inbox empty AND no recent library items
- [ ] Plain text version renders correctly

---

## Technical Considerations

### Cursor Fix
- Single CSS addition, minimal risk
- Can be done in `application.css` or Tailwind config

### Mobile Responsive
- Use Tailwind's existing responsive utilities
- Test with browser dev tools + real device
- Consider `<meta name="viewport">` is set correctly
- May need to adjust some absolute positioning

### Daily Digest
- Timezone handling is complex — start with UTC, add user timezone later
- Email rendering: use Rails layouts, inline CSS for email clients
- Rate limiting: process users in batches if list grows
- Unsubscribe: include one-click unsubscribe link (CAN-SPAM compliance)

---

## Implementation Order

1. **Cursor fix** (30 min) — Quick win, ship immediately
2. **Mobile responsive** (1-2 days) — Iterate view by view
3. **Daily digest** (1 day) — New feature, needs mailer + job + settings

---

## Out of Scope for v1.1

- Push notifications
- Custom digest send times (per-user timezone)
- Weekly digest option
- Digest preview in settings
- Native mobile app

---

## Success Criteria

- Cursor feels native on all interactive elements
- App is comfortably usable on mobile phone
- Daily digest provides value without requiring app open
- No increase in unsubscribe rate after digest launch

---

*Document version: 1.0*
*Created: 2026-01-25*
