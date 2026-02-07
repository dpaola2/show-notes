# Implementation Progress — email-notifications

| Field | Value |
|-------|-------|
| **Branch** | `pipeline/email-notifications` |
| **Primary repo** | `~/projects/show-notes/` |
| **Milestones** | M0–M2 |

## Milestone Status

| Milestone | Description | Status |
|-----------|-------------|--------|
| M0 | Discovery & Alignment | Complete (Stages 1-3) |
| M1 | Signup Notification Mailer & Controller Integration | **Complete** |
| M2 | QA Test Data | **Complete** |

---

## M1: Signup Notification Mailer & Controller Integration

**Status:** Complete
**Date:** 2026-02-07
**Commit:** `21c3104`

### Files Created
- `app/mailers/signup_notification_mailer.rb` — Mailer class with `RECIPIENTS` constant and `new_signup(user)` method
- `app/views/signup_notification_mailer/new_signup.html.erb` — HTML email template with user email and signup timestamp
- `app/views/signup_notification_mailer/new_signup.text.erb` — Plain text email template

### Files Modified
- `app/controllers/sessions_controller.rb` — Added `previously_new_record?` check and `SignupNotificationMailer.new_signup(user).deliver_later` call
- `CLAUDE.md` — Added Codebase Patterns & Gotchas section (auth patterns, mailer conventions, `previously_new_record?` gotcha)

### Test Results
- **This milestone tests:** 9 passing, 0 failing
- **Full test suite:** 250 passing, 0 failing, 0 regressions

### Acceptance Criteria
- [x] EML-001: New user creation triggers notification
- [x] EML-002: Recipient list includes `dpaola2@gmail.com` and `dpaola2-ceo@agentmail.to`
- [x] EML-003: Subject is `"New Show Notes signup: {user email}"`
- [x] EML-004: Body includes user email and signup timestamp
- [x] EML-005: Async via `deliver_later`
- [x] EML-006: Failure doesn't block login (`deliver_later` is async)
- [x] EML-007: Only new users, not returning users
- [x] CFG-001: Recipients as `RECIPIENTS` constant in mailer class

### Spec Gaps
None.

### Notes
- **Gotcha discovered:** `previously_new_record?` is cleared by `update!`. The original architecture placed the check *after* `generate_magic_token!` (which calls `update!`), causing it to always return `false`. Fix: capture the value in a local variable *before* `generate_magic_token!` runs.
- Added codebase patterns to `CLAUDE.md` — authentication flow, mailer conventions, `previously_new_record?` gotcha.

---

## M2: QA Test Data

**Status:** Complete
**Date:** 2026-02-07
**Commit:** `7db3ddf`

### Files Created
- `lib/tasks/seed_signup_notification.rake` — `pipeline:seed_signup_notification` rake task

### Test Results
- **This milestone tests:** N/A (manual QA verification)
- **Full test suite:** 250 passing, 0 failing, 0 regressions

### Acceptance Criteria
- [x] Seed task exists at `lib/tasks/seed_signup_notification.rake`
- [x] Task creates a brand-new user and triggers the notification mailer
- [x] Task is idempotent (destroys and recreates deterministic test user)
- [x] Task prints summary: test email, recipients, verification instructions
- [x] Development: Letter Opener; staging/prod: Resend

### Notes
- Task directly calls `SignupNotificationMailer.new_signup(user).deliver_later` since it bypasses the controller.
- Uses `User.create!` (not `find_or_create_by!`) after explicit destroy — ensures mailer fires every run.
