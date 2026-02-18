# Long-Lived Authentication — PRD

|  |  |
| -- | -- |
| **Product** | Show Notes |
| **Version** | 1 |
| **Author** | Stage 0 (Pipeline) |
| **Date** | 2026-02-08 |
| **Status** | Draft — Review Required |
| **Platforms** | Web only |
| **Level** | [CONFIRM — suggested: 1 (self-contained change to session handling, no new pages/models)] |

---

## 1. Executive Summary

**What:** Make authentication sessions persist across browser restarts so users stay logged in on their devices without re-entering their email and requesting a new magic link each time.

**Why:** The current magic-link auth flow requires a full re-authentication (enter email → receive magic link email → click link) every time the browser is closed or the session cookie expires. This is especially painful when clicking links in digest emails — the user is redirected to the episode page, hits an auth wall, and must complete the full magic-link flow before seeing the content they clicked on. For a single-user app where the user is the only person who receives these digest emails, this friction is disproportionate.

**Key Design Principles:**
- Sessions should persist across browser restarts on any device where the user has authenticated
- The magic-link flow itself remains the sole login method — no passwords
- Security tradeoffs are acceptable for a single-user personal app

---

## 2. Goals & Success Metrics

### Goals
- Eliminate the need to re-authenticate on every browser session
- Make digest email links land the user directly on episode content without an auth wall (if previously authenticated on that browser)
- Support concurrent long-lived sessions across multiple devices (phone, laptop, etc.)

### Success Metrics

| Metric | Target | Timeframe |
|--------|--------|-----------|
| Magic link requests per week (Dave's usage) | Reduce by 80%+ | 7 days |
| Digest email link-to-content friction | Zero extra steps if already authenticated | Immediate |

[NEEDS REVIEW — metrics are inferred from the single-user context; may want to simplify to "it just works"]

---

## 3. Feature Requirements

### Session Persistence

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| SES-001 | After successful magic-link verification, the session persists across browser restarts (does not expire when browser closes) | Web | Must |
| SES-002 | Sessions have a configurable maximum lifetime (e.g., 30 days, 90 days, or "forever") after which re-authentication is required | Web | Must |
| SES-003 | Multiple devices can maintain concurrent active sessions (e.g., phone Safari and laptop Chrome) | Web | Must |
| SES-004 | Logging out on one device does not invalidate sessions on other devices | Web | Should |
| SES-005 | The existing "Logout" action destroys only the current device's session | Web | Must |

### Digest Email Experience

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| DIG-001 | Clicking a tracked digest email link on a device with an active session lands the user directly on the episode page with no auth interruption | Web | Must |
| DIG-002 | Clicking a tracked digest email link on a device without an active session redirects to login, and after magic-link auth, redirects back to the originally requested episode | Web | Must |

### Security

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| SEC-001 | Long-lived session tokens are cryptographically secure and not guessable | Web | Must |
| SEC-002 | ~~Deferred — "Log out everywhere" is not feasible with cookie-only sessions and is overkill for a single-user app~~ | Web | ~~Should~~ |

---

## 4. Platform-Specific Requirements

### Web (Rails)
- Sessions persist via cookie-only approach: configure `expire_after` on the Rails `cookie_store` session
- No new models or migrations required
- The `current_user` helper in `ApplicationController` continues to work transparently (reads `session[:user_id]`, unchanged)
- `TrackingController` remains exempt from authentication (tracking links work without auth, as today)

### iOS
- No changes required — Level 1 project

### Android
- No changes required — Level 1 project

---

## 5. User Flows

### Flow 1: First-Time Login (unchanged)
**Persona:** Dave
**Entry Point:** `/login`

1. User visits Show Notes in a new browser (no existing session)
2. User enters email address
3. System sends magic link email (token valid 15 min)
4. User clicks magic link in email
5. System verifies token, creates a **persistent** session
6. User lands on inbox — session persists across browser restarts
7. **Success:** User does not need to log in again until session expires or they log out
8. **Error:** If token is expired/invalid, redirect to login with error (unchanged)

### Flow 2: Returning to Site (new behavior)
**Persona:** Dave
**Entry Point:** Direct URL or bookmark

1. User opens browser (may have been fully closed since last visit)
2. User navigates to Show Notes
3. System recognizes persistent session — no login required
4. User lands on inbox directly
5. **Success:** Seamless access without re-authentication

### Flow 3: Clicking Digest Email Link (improved)
**Persona:** Dave
**Entry Point:** Link in digest email

1. User taps "Read summary" link in digest email
2. `TrackingController` records the click (no auth required)
3. Redirect to `episodes#show`
4. System recognizes persistent session — no auth wall
5. User sees the episode content immediately
6. **Success:** One tap from email to content
7. **Error (no session):** Redirects to login; after magic-link auth, redirects back to the episode

Note: return-to URL storage confirmed NOT implemented today. DIG-002 requires adding `session[:return_to]` in `require_authentication` and consuming it in `SessionsController#verify`.

### Flow 4: Logging Out
**Persona:** Dave
**Entry Point:** Logout button

1. User clicks "Log out"
2. Current session is destroyed
3. User is redirected to login page
4. Other devices remain logged in
5. **Success:** Only the current device is logged out

### Flow 5: Revoking All Sessions
**Persona:** Dave
**Entry Point:** Settings page

1. User navigates to Settings
2. User clicks "Log out everywhere" [NEEDS REVIEW — UI placement TBD]
3. All sessions across all devices are invalidated
4. Current session is also destroyed; user redirected to login
5. **Success:** All devices require re-authentication

---

## 6. UI Mockups / Wireframes

No significant UI changes. The login form remains the same (no "remember me" checkbox — persistence is the default behavior). The only potential UI addition is a "Log out everywhere" link in Settings, if SEC-002 is implemented:

```
Settings
─────────────────────────────
[existing settings fields]

Session
─────────────────────────────
Log out everywhere
  Ends all active sessions on all devices.
  You will need to log in again.
  [Log out everywhere]
```

[NEEDS REVIEW — "Log out everywhere" may be overkill for a single-user app; could defer]

---

## 7. Backwards Compatibility

N/A — no API or client-facing changes. This is a server-side session configuration change.

### Migration Strategy
- Existing sessions (if any are active at deploy time) will be lost — user will need to re-authenticate once after deploy
- This is acceptable for a single-user app
- No data migration required (cookie-only approach)

---

## 8. Edge Cases & Business Rules

| Scenario | Expected Behavior | Platform |
|----------|-------------------|----------|
| Browser clears cookies | User must re-authenticate via magic link | Web |
| Session reaches maximum lifetime | User must re-authenticate via magic link | Web |
| User clicks digest link in email app's built-in browser | Session may not be shared with main browser — user hits auth wall in embedded browser | Web |
| Multiple tabs open during logout | All tabs in the same browser lose auth (same cookie) | Web |
| Magic link clicked after session already exists | New token verified, session refreshed/extended | Web |
| User on incognito/private browsing | Session does not persist (browser discards cookies) — expected behavior | Web |
| [INFERRED] Cookie size limits if using cookie-store approach | Ensure session data stays well under 4KB browser limit | Web |
| [INFERRED] Deploy/server restart | Cookie-based sessions survive; database-backed sessions survive if using persistent storage | Web |

---

## 9. Export Requirements

N/A.

---

## 10. Out of Scope

- Password-based authentication — Show Notes is magic-link only
- OAuth / social login (Google, GitHub, etc.)
- Two-factor authentication
- Session activity audit log (which devices are logged in, when)
- [DEFINE — anything else explicitly excluded?]

---

## 11. Open Questions

| # | Question | Status | Decision | Blocking? |
|---|----------|--------|----------|-----------|
| 1 | Cookie-only (`expire_after`) vs. database-backed sessions? Cookie-only is simpler but doesn't support "log out everywhere" or per-device session management. Database-backed is more flexible but adds a model + migration. | Resolved | Cookie-only. No `session_store.rb` exists; app uses Rails 8.1 default `cookie_store` with no `expire_after`. Adding `expire_after` is a one-line config change. Database-backed is overkill for a single-user app. | No |
| 2 | What should the session lifetime be? Options: 30 days, 90 days, 1 year, "forever" (until explicit logout or cookie clear). | Open | — | No |
| 3 | Is "return_to" URL storage (redirect back after auth) already implemented? If not, should DIG-002 be in scope? | Resolved | Not implemented. DIG-002 is in scope (promoted to Must). | No |
| 4 | Is "Log out everywhere" (SEC-002) worth building for a single-user app, or is it over-engineering? | Resolved | Deferred — not feasible with cookie-only approach, overkill for single-user app | No |
| 5 | Email app embedded browsers (Gmail app, Apple Mail in-app browser) don't share cookies with Safari/Chrome. Is this a known friction point, or is Dave primarily clicking links in a full browser? | Open | — | No |

> **No blocking questions remain.** Q1 resolved (cookie-only). Remaining open questions are non-blocking.

---

## 12. Release Plan

### Phases

| Phase | What Ships | Flag | Audience |
|-------|-----------|------|----------|
| Phase 1 | Long-lived sessions (SES-001 through SES-005, DIG-001) | No flag needed | Dave (single user) |

### Feature Flag Strategy
- No feature flag needed — single-user app, change is immediately beneficial
- Rollback plan: revert the session configuration change (re-deploy previous version)

---

## 13. Assumptions

- Show Notes is and will remain a single-user application (Dave is the only user)
- The primary frustration is re-authenticating after browser close, not after extended periods of inactivity
- Magic-link email delivery is fast enough that re-authentication (when needed) is not critically painful — the issue is frequency, not per-instance duration
- Browser cookie storage is not aggressively cleared by the user or browser settings
- Confirmed: the session cookie store is the current Rails session backend (no `session_store.rb` initializer exists; Rails 8.1 default `cookie_store`)

---

## Appendix: Linked Documents

| Document | Link |
|----------|------|
| Inbox source | `inbox/long-lived authentication.md` |
| Current auth implementation | `app/controllers/sessions_controller.rb`, `app/models/user.rb` |
| Session config | `config/application.rb` or `config/initializers/session_store.rb` (if exists) |
