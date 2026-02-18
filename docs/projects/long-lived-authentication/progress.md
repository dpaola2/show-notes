# Implementation Progress — long-lived-authentication

| Field | Value |
|-------|-------|
| **Branch** | `pipeline/long-lived-authentication` |
| **Primary repo** | `~/projects/show-notes/` |
| **Milestones** | M0–M2 |

## Milestone Status

| Milestone | Description | Status |
|-----------|-------------|--------|
| M0 | Discovery & Alignment | Complete (Stages 0-3) |
| M1 | Session Persistence + Return-To URL | **Complete** |
| M2 | QA Verification | **Complete** |

---

## M1: Session Persistence + Return-To URL

**Status:** Complete
**Date:** 2026-02-08
**Commit:** `6441141`

### Files Created
- `config/initializers/session_store.rb` — configures cookie store with `expire_after: 1.year`

### Files Modified
- `app/controllers/application_controller.rb` — added `session[:return_to]` storage in `require_authentication` (GET requests only)
- `app/controllers/sessions_controller.rb` — changed `verify` action to redirect to `session.delete(:return_to) || root_path`

### Test Results
- **This milestone tests:** 10 passing, 0 failing (`spec/requests/session_persistence_spec.rb`)
- **Existing session tests:** 19 passing, 0 regressions (`spec/requests/sessions_spec.rb`)
- **Full suite:** 1 pre-existing failure (unrelated `opml_import_service_spec.rb:203` — known cumulative matcher issue)

### Acceptance Criteria
- [x] SES-001: Session persists across browser restarts (cookie has `Expires`/`Max-Age` attribute)
- [x] SES-002: Session lifetime configured to 1 year via `expire_after: 1.year`
- [x] SES-003: Multiple browsers can maintain concurrent sessions (inherent to cookie store)
- [x] SES-005: Logout destroys only the current browser's session
- [x] DIG-001: Authenticated user clicks digest link → lands on episode directly
- [x] DIG-002: Unauthenticated user → login → redirect back to episode
- [x] DIG-002 (GET-only): Return-to URL only stored for GET requests
- [x] DIG-002 (cleanup): Stored return-to URL consumed after redirect
- [x] SEC-001: Session cookie encrypted via Rails' secret_key_base
- [x] Existing logout behavior unchanged
- [x] Existing magic-link flow unchanged

### Spec Gaps
None

### Notes
- No new conventions discovered — all patterns used (session.delete for consume-once, request.original_url, request.get?) are standard Rails
- Implementation was 3 files, 4 lines added / 1 line modified — the smallest milestone the pipeline has produced
- Pipeline-scoped: tiny config-only projects flow through the pipeline without overhead — each stage scales proportionally

---

## M2: QA Verification

**Status:** Complete
**Date:** 2026-02-08
**Commit:** N/A (verification only, no code changes)

### Test Results
- **Full suite:** 10 new + 19 existing session tests passing, 0 regressions
- **Pre-existing failure:** `opml_import_service_spec.rb:203` (unrelated, known issue)

### Acceptance Criteria
- [x] Existing specs pass: `bundle exec rspec spec/requests/sessions_spec.rb` — 19 passing
- [x] All specs pass: `bundle exec rspec` — 1 pre-existing failure only (unrelated)

### Spec Gaps
None

### Notes
- M2 is verification-only — confirmed during M1's regression check
