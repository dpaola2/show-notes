# Implementation Status

Tracks what has been built against the PRD and Technical Gameplan requirements.

**Legend**: ✅ Done | ⚠️ Partial | ❌ Not Started | 🔧 Stubbed

---

## Phase Summary

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: Core Loop | ⚠️ 90% | Missing: real feed refresh, Turbo Streams for processing status |
| Phase 2: Triage Flow | ✅ Done | All episode lifecycle transitions work |
| Phase 3: Polish & Auth | ⚠️ 30% | Auth stubbed, search partially done, cost estimates missing |
| Phase 4: PWA | ❌ Not Started | |

---

## Authentication

| Requirement | Status | Implementation | Notes |
|-------------|--------|----------------|-------|
| Magic link authentication | 🔧 Stubbed | `User.first` in controllers | **BLOCKER**: No login flow exists |
| User model with tokens | ✅ Done | `app/models/user.rb` | `generate_magic_token!`, `magic_token_valid?` |
| SessionsController | ❌ Not Started | | Need new, create, verify actions |
| Email sending | ❌ Not Started | | Need Action Mailer setup |

**Current behavior**: All controllers use `def current_user; User.first; end` as a temporary stub. Anyone can access any user's data.

---

## Inbox (Triage) — PRD Section

| Requirement | Priority | Status | Implementation |
|-------------|----------|--------|----------------|
| Chronological list of new episodes | P0 | ✅ Done | `InboxController#index`, sorted by `published_at DESC` |
| "Add to Library" action | P0 | ✅ Done | `InboxController#add_to_library` |
| "Skip" action | P0 | ✅ Done | `InboxController#skip` → moves to trash |
| Episodes persist until acted upon | P0 | ✅ Done | No auto-expiration logic |
| Badge count showing Inbox size | P1 | ❌ Not Started | Need to add to nav |

---

## Trash — PRD Section

| Requirement | Priority | Status | Implementation |
|-------------|----------|--------|----------------|
| Holds skipped episodes | P0 | ✅ Done | `location: :trash` enum |
| Restore to Inbox action | P1 | ✅ Done | `TrashController#restore` |
| Auto-delete after 90 days | P1 | ⚠️ Partial | `CleanupTrashJob` exists, recurring schedule not configured |
| Manual empty trash | P2 | ❌ Not Started | |

**Note**: `CleanupTrashJob` is written but `config/recurring.yml` doesn't exist yet to schedule it.

---

## Show Archive (Podcast Browser) — PRD Section

| Requirement | Priority | Status | Implementation |
|-------------|----------|--------|----------------|
| Browse full episode history | P0 | ✅ Done | `PodcastsController#show` |
| "Add to Inbox" action | P0 | ✅ Done | `InboxController#create` |
| "Add to Library" action | P0 | ✅ Done | `InboxController#add_to_library` with `episode_id` |
| Silent duplicate handling | P0 | ✅ Done | `find_or_initialize_by` + move logic |

---

## Library — PRD Section

| Requirement | Priority | Status | Implementation |
|-------------|----------|--------|----------------|
| List of active episodes | P0 | ✅ Done | `LibraryController#index` |
| Status indicators | P0 | ✅ Done | Shows pending/downloading/transcribing/summarizing/ready/error |
| Detailed error states | P0 | ⚠️ Partial | Shows `processing_error` but could be more helpful |
| Episode detail view | P0 | ✅ Done | `LibraryController#show` |
| "Done" action (→ Archive) | P0 | ✅ Done | `LibraryController#archive` |
| Filter by podcast | P2 | ❌ Not Started | |

---

## Archive — PRD Section

| Requirement | Priority | Status | Implementation |
|-------------|----------|--------|----------------|
| Holds completed episodes | P0 | ✅ Done | `location: :archive` enum |
| Browse archived episodes | P0 | ✅ Done | `ArchiveController#index`, `#show` |
| Restore to Library | P1 | ✅ Done | `ArchiveController#restore` |

---

## AI Summarization — PRD Section

| Requirement | Priority | Status | Implementation |
|-------------|----------|--------|----------------|
| Cost estimate before processing | P0 | ⚠️ Partial | Model method exists, not shown in UI prominently |
| Automatic transcription | P0 | ✅ Done | `ProcessEpisodeJob` → `WhisperClient` |
| AI-generated summary | P0 | ✅ Done | `ProcessEpisodeJob` → `ClaudeClient` |
| Notable quotes with timestamps | P0 | ✅ Done | `quotes` jsonb field, displayed in detail view |
| Background processing | P1 | ✅ Done | Solid Queue job |
| Status updates (Turbo Streams) | P1 | ❌ Not Started | Job doesn't broadcast updates |
| Retry failed transcriptions | P1 | ⚠️ Partial | Can click "Regenerate" but no auto-retry |
| Regenerate summary only | P1 | ✅ Done | `LibraryController#regenerate` deletes summary, re-runs job |

---

## Audio Playback — PRD Section

| Requirement | Priority | Status | Implementation |
|-------------|----------|--------|----------------|
| Play/pause | P0 | ✅ Done | Native `<audio>` element |
| Seek bar | P0 | ✅ Done | Native `<audio>` controls |
| Jump to timestamp (quote tap) | P0 | ✅ Done | `audio_seek_controller.js` |
| Background audio | P1 | ❌ Not Started | Need Media Session API |
| Playback speed control | P2 | ❌ Not Started | |
| Skip forward/back buttons | P2 | ❌ Not Started | |

---

## Podcast Management — PRD Section

| Requirement | Priority | Status | Implementation |
|-------------|----------|--------|----------------|
| Search for podcasts | P0 | ✅ Done | `PodcastsController#index` → `PodcastIndexClient` |
| Subscribe/unsubscribe | P0 | ✅ Done | `PodcastsController#create`, `#destroy` |
| View subscriptions list | P0 | ✅ Done | `SubscriptionsController#index` |
| OPML import | P1 | ❌ Not Started | |
| OPML export | P2 | ❌ Not Started | |

---

## Search — PRD Section

| Requirement | Priority | Status | Implementation |
|-------------|----------|--------|----------------|
| Search across summaries | P1 | ⚠️ Partial | `searchable_text` column exists, no UI |
| Results link to episode | P1 | ❌ Not Started | No search controller |

**Note**: The `Summary` model has `searchable_text` and `update_searchable_text` callback, but the tsvector index and search controller aren't implemented.

---

## Background Jobs — Gameplan

| Job | Status | Implementation | Notes |
|-----|--------|----------------|-------|
| `FetchPodcastFeedJob` | ✅ Done | `app/jobs/fetch_podcast_feed_job.rb` | Fetches RSS, creates episodes |
| `ProcessEpisodeJob` | ✅ Done | `app/jobs/process_episode_job.rb` | Download → Whisper → Claude |
| `RefreshAllFeedsJob` | ❌ Not Started | | Enqueue feed fetches for all subscribed podcasts |
| `CleanupTrashJob` | ✅ Done | `app/jobs/cleanup_trash_job.rb` | Deletes episodes trashed >90 days |
| Recurring schedule | ❌ Not Started | `config/recurring.yml` missing | Need to configure Solid Queue |

---

## API Clients — Gameplan

| Client | Status | Implementation | Notes |
|--------|--------|----------------|-------|
| `PodcastIndexClient` | ✅ Done | `app/services/podcast_index_client.rb` | Search, podcast details, episodes |
| `PodcastFeedParser` | ✅ Done | `app/services/podcast_feed_parser.rb` | RSS parsing with Feedjira |
| `WhisperClient` | ✅ Done | `app/services/whisper_client.rb` | Transcription API |
| `ClaudeClient` | ✅ Done | `app/services/claude_client.rb` | Summarization API |

---

## UI/UX — Gameplan

| Feature | Status | Implementation |
|---------|--------|----------------|
| Navigation header | ✅ Done | `application.html.erb` |
| Mobile-responsive nav | ✅ Done | Icons on small screens |
| Flash messages | ✅ Done | Auto-dismiss after 5s |
| Turbo Frames for triage | ⚠️ Partial | Frame tags present, not fully utilized |
| Turbo Streams for updates | ❌ Not Started | No real-time updates |

---

## Data Model — Gameplan

| Model | Status | Notes |
|-------|--------|-------|
| User | ✅ Done | Magic token fields present |
| Podcast | ✅ Done | |
| Subscription | ✅ Done | Unique user+podcast |
| Episode | ✅ Done | |
| UserEpisode | ✅ Done | location/processing_status enums |
| Transcript | ✅ Done | |
| Summary | ✅ Done | sections/quotes jsonb |

---

## Testing

| Area | Status | Count |
|------|--------|-------|
| Model specs | ✅ Done | 65 examples |
| Service specs | ✅ Done | 45 examples |
| Request specs | ✅ Done | 18 examples |
| **Total** | ✅ Done | **128 examples, 0 failures** |

---

## Priority Items to Complete

### Must Have (before real use)

1. **Authentication** — Currently anyone can access everything
   - Create `SessionsController` with magic link flow
   - Add `before_action :require_authentication` to all controllers
   - Set up Action Mailer for sending magic link emails

2. **Recurring Job Schedule** — Feeds won't auto-refresh
   - Create `config/recurring.yml` with RefreshAllFeedsJob schedule
   - Create `RefreshAllFeedsJob` to enqueue individual feed fetches

3. **Cost Estimate Display** — Users don't see cost before processing
   - Add prominent cost display in Inbox cards
   - Show confirmation before expensive episodes

### Should Have (for good experience)

4. **Turbo Streams for Processing** — No feedback during processing
   - Broadcast status updates from `ProcessEpisodeJob`
   - Update Library cards in real-time

5. **Search UI** — Search infrastructure exists but no UI
   - Add search route and controller
   - Build search results page

6. **Inbox Badge** — Can't see unread count in nav

### Nice to Have

7. Background audio (Media Session API)
8. OPML import
9. Playback speed control

---

*Last updated: 2025-01-25*
