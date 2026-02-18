---
pipeline_stage: 5
pipeline_stage_name: implementation
pipeline_project: "shareable-episode-cards"
pipeline_m1_started_at: "2026-02-18T17:02:00-0500"
pipeline_m1_completed_at: "2026-02-18T17:10:54-0500"
---

# Implementation Progress — shareable-episode-cards

| Field | Value |
|-------|-------|
| **Branch** | `dave/shareable-episode-cards` |
| **Repo** | /Users/dave/projects/show-notes |
| **Milestones** | M0–M5 |

## Milestone Status

| Milestone | Description | Status |
|-----------|-------------|--------|
| M0 | Discovery & Alignment | Complete (Stages 1-3) |
| M1 | Data Model, Public Page & OG Meta Tags | **Complete** |
| M2 | OG Image Generation | Pending |
| M3 | Share UI, Tracking & UTM Attribution | Pending |
| M4 | QA Test Data | Pending |
| M5 | Edge Cases, Empty States & Polish | Pending |

---

## M1: Data Model, Public Page & OG Meta Tags

**Status:** Complete
**Date:** 2026-02-18
**Commit:** `e00eeae`

### Files Created
- `db/migrate/20260218220324_create_active_storage_tables.active_storage.rb` — Active Storage framework tables
- `db/migrate/20260218220325_create_share_events.rb` — share_events table with indexes
- `db/migrate/20260218220326_add_referral_source_to_users.rb` — referral_source column on users
- `app/models/share_event.rb` — ShareEvent model with validations, associations, scopes
- `app/controllers/public_episodes_controller.rb` — public episode page + share action (no auth)
- `app/views/layouts/public.html.erb` — minimal public layout with robots meta tag
- `app/views/public_episodes/show.html.erb` — episode summary display, OG meta tags, CTA, share placeholder

### Files Modified
- `app/models/episode.rb` — added has_many :share_events, has_one_attached :og_image, og_image_url, shareable?
- `app/models/user.rb` — added has_many :share_events, dependent: :nullify
- `config/routes.rb` — added /e/:id and POST /e/:id/share routes
- `db/schema.rb` — updated with new tables
- `AGENTS.md` — added Active Storage URL and public controller patterns

### Test Results
- **This milestone tests:** 53 passing, 0 failing (all M1 criteria verified)
- **Prior milestone tests:** N/A (first milestone)
- **Future milestone tests:** 1 failing in shared test file (TRK-003 UTM logging — M3), 2 spec files fail to load (M2 classes don't exist yet) — both expected

### Acceptance Criteria
- [x] PUB-001: Episode synopsis pages accessible at `/e/:id` without authentication
- [x] PUB-002: Public page displays episode title, podcast name, and podcast artwork
- [x] PUB-003: Public page displays the full AI summary (all sections and quotes)
- [x] PUB-004: Public page includes a prominent CTA linking to the signup flow
- [x] PUB-005: Public page includes OG meta tags (og:title, og:description, og:url, og:image when attached)
- [x] PUB-006: Public page has a clean, readable design using the `public` layout (no nav bar)
- [x] PUB-007: Management actions NOT accessible from public page (no audio URL exposed)
- [x] PUB-008: Public page URL is stable and permanent (`/e/:id`)
- [x] Data model: `share_events` table created with indexes on episode_id, user_id, and (episode_id, share_target)
- [x] Data model: `referral_source` column added to `users` table (nullable, no backfill)
- [x] Data model: Active Storage tables installed
- [x] Model: ShareEvent with validations (share_target inclusion) and associations
- [x] Model: Episode gains has_many :share_events, has_one_attached :og_image, og_image_url, shareable?
- [x] Model: User gains has_many :share_events, dependent: :nullify
- [x] Public page returns friendly 404 for non-existent episodes
- [x] Public page handles episodes without summaries ("Summary not yet available")
- [x] Public page is SEO-indexable (robots meta tag: index, follow)

### Spec Gaps
- **TRK-003 UTM logging test** (`spec/requests/public_episodes_spec.rb:182`): Uses `expect(Rails.logger).to receive(:info).with(/utm_source/)` which creates a strict stub on BroadcastLogger. During request processing, Rails LogSubscribers call `.info` with blocks (no positional args), causing the mock to fail with "unexpected arguments." The controller code IS logging correctly, but the test pattern conflicts with framework-level logging. M3 implementation should address this — either by using `allow` + `expect` or by adjusting the logging approach.

### Notes
- `og_image_url` requires explicit host parameter since `default_url_options[:host]` is not globally configured. Added fallback: `ENV["APP_HOST"] || "localhost:3000"`. This works in test (model specs), development, and production.
- The `public` layout is modeled after the `sessions` layout but simpler — no flash messages (public pages don't set flashes).
- Share button on public page is a placeholder (HTML only). Stimulus controller wiring happens in M3.
- POST `/e/:id/share` works for both authenticated and unauthenticated users — associates `current_user` when available, nil otherwise.
