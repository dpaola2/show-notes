# New User Signup Email Notifications — PRD

|  |  |
| -- | -- |
| **Product** | Show Notes |
| **Version** | 1 |
| **Author** | Stage 0 (Pipeline) |
| **Date** | 2026-02-07 |
| **Status** | Draft — Review Required |
| **Platforms** | Web only |
| **Level** | 1 |

---

## 1. Executive Summary

**What:** Send an email notification to a hardcoded list of internal recipients whenever a new user signs up for Show Notes. This is an internal awareness notification — it does not go to the signing-up user and has no user-facing UI.

**Why:** The team needs visibility into new signups as they happen, without having to check the database or admin panel manually.

**Key Design Principles:**
- Internal only — notifications go to the team, never to the end user signing up
- Simple and reliable — use ActionMailer with the existing Resend integration
- Hardcoded recipients — no admin UI for managing the recipient list; changes go through code

---

## 2. Goals & Success Metrics

### Goals
- Receive an email notification within minutes of each new user signup
- Include enough context in the email to understand who signed up (email, timestamp)

### Success Metrics

| Metric | Target | Timeframe |
|--------|--------|-----------|
| Notification delivery rate | 100% of new user signups trigger an email | Ongoing |
| Delivery latency | < 5 minutes from signup to inbox (Solid Queue + Resend) | Ongoing |

---

## 3. Feature Requirements

### Email Delivery

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| EML-001 | When a new user record is created via the login flow (`find_or_create_by!`), an email notification is sent to all configured internal recipients | Web | Must |
| EML-002 | The recipient list includes `dpaola2@gmail.com` and `dpaola2-ceo@agentmail.to` | Web | Must |
| EML-003 | The email subject line clearly identifies it as a new signup notification (e.g., "New Show Notes signup: {user email}") | Web | Must |
| EML-004 | The email body includes: user's email address and signup timestamp | Web | Must |
| EML-005 | Email delivery is asynchronous via `deliver_later` (Solid Queue), consistent with existing mailer usage | Web | Must |
| EML-006 | If email delivery fails, the failure is logged but does not prevent the user from completing login | Web | Must |
| EML-007 | Notification fires only for newly created users, not for existing users logging in again (the `find_or_create_by!` call handles both cases) | Web | Must |

### Configuration

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| CFG-001 | The recipient list is defined as a constant in the mailer class (consistent with the app's simplicity — no ENV var needed for 2 static addresses) | Web | Should |

---

## 4. Platform-Specific Requirements

### Web (Rails)
- Use ActionMailer with Resend (already configured: `config.action_mailer.delivery_method = :resend`)
- Use `deliver_later` via Solid Queue (already configured: `config.active_job.queue_adapter = :solid_queue`)
- Follow existing mailer patterns: inherit from `ApplicationMailer` (sender: `noreply@listen.davepaola.com`), single-purpose methods
- Existing mailers to reference: `UserMailer` (magic links), `DigestMailer` (daily digest)

### iOS
- No changes required — Level 1 project

### Android
- No changes required — Level 1 project

### API
- No changes required — Level 1 project

---

## 5. User Flows

### Flow 1: New User's First Login (Triggers Notification)
**Persona:** Someone visiting Show Notes for the first time
**Entry Point:** Login page (`/login`)

1. User enters their email on the login page
2. `SessionsController#create` calls `User.find_or_create_by!(email:)`
3. Since no user exists with that email, a new `User` record is created
4. Notification mailer fires asynchronously (`deliver_later`) to internal recipients
5. Magic link email is also sent to the user (existing behavior, unchanged)
6. **Success:** Internal recipients receive a "new signup" email; user receives their magic link as usual
7. **Error:** If notification email fails, it is logged; the user's magic link flow is unaffected

### Flow 2: Existing User Logs In (No Notification)
**Persona:** Returning user
**Entry Point:** Login page (`/login`)

1. User enters their email on the login page
2. `SessionsController#create` calls `User.find_or_create_by!(email:)`
3. User already exists — no new record created
4. No signup notification fires
5. Magic link email is sent as usual (existing behavior, unchanged)

---

## 6. UI Mockups / Wireframes

N/A — backend changes only. No user-facing UI is added or modified.

---

## 7. Backwards Compatibility

N/A — no API or client-facing changes. This is an internal backend addition.

---

## 8. Edge Cases & Business Rules

| Scenario | Expected Behavior | Platform |
|----------|-------------------|----------|
| Resend is down or rate-limited | Login completes normally; notification delivery failure is logged by Solid Queue | Web |
| Multiple new users sign up simultaneously | Each signup triggers its own independent notification email | Web [INFERRED] |
| Recipient email address bounces | Handled by Resend; no application-level retry logic needed | Web [INFERRED] |
| User record created via Rails console or seed data | No notification — hook is in the controller flow, not a model callback [NEEDS REVIEW — confirm this is the desired behavior] | Web |
| Existing user logs in | No notification sent — `find_or_create_by!` finds the existing record, no new user created | Web |
| User enters an invalid email format | Validation fails (`ActiveRecord::RecordInvalid`), no user created, no notification sent (existing error handling in `SessionsController`) | Web |

---

## 9. Export Requirements

N/A.

---

## 10. Out of Scope

- Admin UI for managing notification recipients
- User-facing welcome/confirmation emails (separate concern)
- SMS or push notification channels
- Notification preferences or unsubscribe functionality
- Analytics or tracking of notification delivery
- Notifications for user actions other than signup (e.g., subscription changes)

---

## 11. Open Questions

| # | Question | Status | Decision | Blocking? |
|---|----------|--------|----------|-----------|
| 1 | Does Show Notes have ActionMailer configured with a working email delivery service? | Resolved | Yes — Resend gem, configured in production.rb and initializer | No |
| 2 | Does Show Notes use background jobs? | Resolved | Yes — Solid Queue (Rails 8 default), already used for `deliver_later` | No |
| 3 | How are users created? | Resolved | Custom magic link auth — `User.find_or_create_by!(email:)` in `SessionsController#create` | No |
| 4 | Should notifications fire for ALL user creation events (including console/seed), or only via the web login flow? | Open | Recommend controller-level only (not model callback) | No |
| 5 | Is there an existing mailer to follow as a pattern? | Resolved | Yes — `UserMailer` and `DigestMailer`, both inherit `ApplicationMailer` | No |

> **No blocking questions — this PRD is ready for pipeline intake (after human review).**

---

## 12. Release Plan

### Phases

| Phase | What Ships | Flag | Audience |
|-------|-----------|------|----------|
| Phase 1 | Signup notification emails to hardcoded recipients | None — always on | Internal team only |

### Feature Flag Strategy
- No feature flag needed — this is an internal notification with no user-facing impact. Deploy and it's live.

---

## 13. Assumptions

- Resend delivery is reliable and doesn't need application-level retry logic
- The recipient list is small and static enough to hardcode (2 addresses)
- The User model has no `name` field — email address is the only identifying information available for the notification
- Signup volume is very low — no batching or rate limiting needed
- Controller-level hook (not model callback) is appropriate since we only want web-flow signups to trigger notifications

---

## Appendix: Linked Documents

| Document | Link |
|----------|------|
| Source notes | `inbox/email-notifications.md` |
| Show Notes PIPELINE.md | `~/projects/show-notes/PIPELINE.md` |
