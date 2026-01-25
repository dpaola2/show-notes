# Show Notes — Technical Gameplan

## Stack Summary

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Ruby | 3.3.10 | Matches local environment |
| Framework | Rails 8 + Hotwire | Batteries included, great for this app shape |
| Frontend | Turbo + Stimulus + Tailwind | Server-rendered, minimal JS, utility-first CSS |
| Database | PostgreSQL | Relational model fits well, Heroku provides managed |
| Background Jobs | Solid Queue | Rails 8 default, DB-backed, no Redis dependency |
| Hosting | Heroku | Push-to-deploy, managed Postgres, familiar |
| Podcast API | Podcast Index | Free, open, good search |
| Audio | Stream from source | No storage costs, play directly from podcast CDN |
| Auth | Magic link (passwordless) | Simple, secure, no passwords to manage |
| Config | Environment variables | No Rails credentials; simpler with Heroku |
| Transcription | AssemblyAI | URL-based (no upload limit), ~$0.0065/sec |
| Summarization | Claude API | Strong summarization, quote extraction |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Heroku                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │   Rails Web     │    │  Solid Queue    │                    │
│  │   (Puma)        │    │  Worker         │                    │
│  └────────┬────────┘    └────────┬────────┘                    │
│           │                      │                              │
│           └──────────┬───────────┘                              │
│                      │                                          │
│                      ▼                                          │
│           ┌─────────────────┐                                   │
│           │   PostgreSQL    │                                   │
│           │   (Heroku)      │                                   │
│           └─────────────────┘                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
    │  Podcast    │     │ AssemblyAI  │     │   Claude    │
    │  Index API  │     │             │     │   API       │
    └─────────────┘     └─────────────┘     └─────────────┘
```

---

## Data Model

Multi-user from v1: each user has their own subscriptions, inbox, library, and archive.

```ruby
# Core models

User
├── email (string, unique)
├── magic_token (string, nullable)
├── magic_token_expires_at (datetime, nullable)
└── timestamps

Podcast
├── guid (string, unique, from Podcast Index)
├── title (string)
├── author (string)
├── description (text)
├── feed_url (string)
├── artwork_url (string)
├── last_fetched_at (datetime)
└── timestamps
# Note: Podcasts are shared across users; subscriptions link them

Subscription
├── user_id (references User)
├── podcast_id (references Podcast)
└── timestamps
# User subscribes to podcasts via this join table

Episode
├── guid (string, unique, from feed)
├── podcast_id (references Podcast)
├── title (string)
├── description (text)
├── audio_url (string)
├── duration_seconds (integer)  # from RSS feed, used for cost estimate
├── published_at (datetime)
└── timestamps
# Episodes are shared; user-specific state is in UserEpisode

UserEpisode
├── user_id (references User)
├── episode_id (references Episode)
├── location (enum: inbox, library, archive, trash)
├── trashed_at (datetime, nullable)  # for 90-day auto-delete
├── processing_status (enum: pending, downloading, transcribing, summarizing, ready, error)
├── processing_error (text, nullable)
└── timestamps
# Per-user episode state (location, processing status)

Transcript
├── episode_id (references Episode)
├── content (text)  # full transcript with timestamps
└── timestamps
# Shared across users (same transcript for same episode)

Summary
├── episode_id (references Episode)
├── sections (jsonb)  # array of {title, content, start_time, end_time}
├── quotes (jsonb)    # array of {text, start_time, end_time}
└── timestamps
# Shared across users (same summary for same episode)
```

**Key multi-user insight**: Transcripts and Summaries are expensive to generate, so they're shared. If User A processes an episode and User B later adds the same episode to their library, User B gets the existing transcript/summary instantly (no reprocessing cost).


### Location State Machine

```
Episode locations and valid transitions:

    inbox ──────► library ──────► archive
      │              │               │
      │              │               │
      ▼              │               │
    trash ◄──────────┘               │
      │                              │
      │         ┌────────────────────┘
      ▼         ▼
  [auto-delete after 90 days]

Valid transitions:
- inbox → library (add to library)
- inbox → trash (skip)
- library → archive (done)
- archive → library (restore)
- trash → inbox (restore)
- Any location → target (silent move from Show Archive)
```

---

## Background Jobs

### Scheduling with Solid Queue

Solid Queue has built-in recurring job support — no external scheduler needed.

```yaml
# config/recurring.yml
production:
  refresh_feeds:
    class: RefreshAllFeedsJob
    schedule: every 6 hours

  cleanup_trash:
    class: CleanupTrashJob
    schedule: every day at 3am
```

```ruby
# config/application.rb
config.solid_queue.recurring_schedule = Rails.root.join("config/recurring.yml")
```

---

### Job: RefreshAllFeedsJob

Triggered: Every 6 hours (via Solid Queue recurring schedule)

```ruby
class RefreshAllFeedsJob < ApplicationJob
  def perform
    # Only refresh podcasts that have at least one subscriber
    Podcast.joins(:subscriptions).distinct.find_each do |podcast|
      FetchPodcastFeedJob.perform_later(podcast.id)
    end
  end
end
```

### Job: FetchPodcastFeedJob

Triggered: On subscribe, and by RefreshAllFeedsJob every 6 hours

```ruby
class FetchPodcastFeedJob < ApplicationJob
  def perform(podcast_id, initial_fetch: false)
    podcast = Podcast.find(podcast_id)
    feed = PodcastFeedParser.parse(podcast.feed_url)
    subscribers = podcast.subscriptions.includes(:user)

    episodes_to_process = feed.episodes
    # On initial subscribe, only add last 10 episodes
    episodes_to_process = episodes_to_process.first(10) if initial_fetch

    episodes_to_process.each do |episode_data|
      episode = podcast.episodes.find_or_initialize_by(guid: episode_data.guid)

      if episode.new_record?
        episode.assign_attributes(
          title: episode_data.title,
          description: episode_data.description,  # Original show notes
          audio_url: episode_data.audio_url,
          duration_seconds: episode_data.duration,
          published_at: episode_data.published_at
        )
        episode.save!

        # Create inbox entry for each subscriber
        subscribers.each do |subscription|
          subscription.user.user_episodes.create!(
            episode: episode,
            location: :inbox
          )
        end
      end
    end

    podcast.update!(last_fetched_at: Time.current)
  end
end

# Called from PodcastsController#create:
# FetchPodcastFeedJob.perform_later(podcast.id, initial_fetch: true)
```

### Job: ProcessEpisodeJob

Triggered: When episode added to Library

```ruby
class ProcessEpisodeJob < ApplicationJob
  def perform(user_episode_id)
    user_episode = UserEpisode.find(user_episode_id)
    episode = user_episode.episode

    # Check if another user already processed this episode
    if episode.transcript.present? && episode.summary.present?
      user_episode.update!(processing_status: :ready)
      return
    end

    # Step 1: Download audio to temp file
    user_episode.update!(processing_status: :downloading)
    audio_file = download_audio(episode.audio_url)

    # Step 2: Transcribe with Whisper (if not already done)
    unless episode.transcript.present?
      user_episode.update!(processing_status: :transcribing)
      transcript = WhisperClient.transcribe(audio_file)
      episode.create_transcript!(content: transcript.to_json)
    end

    # Step 3: Summarize with Claude (if not already done)
    unless episode.summary.present?
      user_episode.update!(processing_status: :summarizing)
      summary = ClaudeClient.summarize(episode.transcript.content)
      episode.create_summary!(
        sections: summary.sections,
        quotes: summary.quotes
      )
    end

    user_episode.update!(processing_status: :ready)

  rescue => e
    user_episode.update!(
      processing_status: :error,
      processing_error: e.message
    )
  ensure
    audio_file&.delete
  end
end
```

**Note**: Transcripts and summaries are shared across users. If the episode was already processed by another user, this job completes instantly.

### Job: CleanupTrashJob

Triggered: Daily at 3am (via Solid Queue recurring schedule)

```ruby
class CleanupTrashJob < ApplicationJob
  def perform
    UserEpisode
      .where(location: :trash)
      .where("trashed_at < ?", 90.days.ago)
      .destroy_all
  end
end
```

---

## External Service Integrations

### Podcast Index

```ruby
# app/services/podcast_index_client.rb
class PodcastIndexClient
  BASE_URL = "https://api.podcastindex.org/api/1.0"

  def search(query)
    get("/search/byterm", q: query)
  end

  def episodes(feed_id)
    get("/episodes/byfeedid", id: feed_id)
  end

  private

  def get(path, params = {})
    # Podcast Index requires auth headers:
    # X-Auth-Key, X-Auth-Date, Authorization (SHA-1 hash)
  end
end
```

### OpenAI Whisper

```ruby
# app/services/whisper_client.rb
class WhisperClient
  def self.transcribe(audio_file)
    client = OpenAI::Client.new

    response = client.audio.transcribe(
      model: "whisper-1",
      file: audio_file,
      response_format: "verbose_json",  # includes timestamps
      timestamp_granularities: ["segment"]
    )

    response
  end

  def self.estimate_cost_cents(duration_seconds)
    minutes = (duration_seconds / 60.0).ceil
    (minutes * 0.6).ceil  # $0.006/min = 0.6 cents/min
  end
end
```

### Claude API

```ruby
# app/services/claude_client.rb
class ClaudeClient
  SUMMARIZE_PROMPT = <<~PROMPT
    You are summarizing a podcast episode transcript. Create:

    1. A multi-section breakdown of the episode (3-6 sections)
       - Each section should have a title and 2-4 sentence summary
       - Include approximate start/end timestamps

    2. 3-5 notable quotes worth highlighting
       - Include the exact timestamp for each quote
       - Pick quotes that are insightful, surprising, or memorable

    Return as JSON:
    {
      "sections": [
        {"title": "...", "content": "...", "start_time": 123, "end_time": 456}
      ],
      "quotes": [
        {"text": "...", "start_time": 123, "end_time": 130}
      ]
    }
  PROMPT

  def self.summarize(transcript)
    client = Anthropic::Client.new

    response = client.messages.create(
      model: "claude-sonnet-4-20250514",
      max_tokens: 4096,
      messages: [
        { role: "user", content: "#{SUMMARIZE_PROMPT}\n\nTranscript:\n#{transcript}" }
      ]
    )

    JSON.parse(response.content.first.text)
  end
end
```

---

## Key Views & Controllers

### Controllers

```
PodcastsController
├── index    # Browse/search podcasts (Podcast Index)
├── show     # Show archive for a podcast
├── create   # Subscribe (fetches last 10 episodes to Inbox)
└── destroy  # Unsubscribe

SubscriptionsController
├── index    # List user's subscribed podcasts

InboxController
├── index    # List inbox episodes
├── create   # POST - add episode to inbox (from Show Archive)
├── add_to_library  # POST - move to library, start processing
└── skip     # POST - move to trash

LibraryController
├── index    # List library episodes
├── show     # Episode detail (summary + audio)
├── archive  # POST - move to archive
└── regenerate # POST - re-run summarization

ArchiveController
├── index    # List archived episodes
├── show     # Episode detail
└── restore  # POST - move back to library

TrashController
├── index    # List trashed episodes
└── restore  # POST - move back to inbox

SessionsController
├── new      # Enter email for magic link
├── create   # Send magic link email
└── verify   # GET with token - log in
```

### Turbo Frames

```erb
# Inbox with inline actions
<turbo-frame id="inbox">
  <% @episodes.each do |episode| %>
    <turbo-frame id="<%= dom_id(episode) %>">
      <%= render "episodes/inbox_card", episode: episode %>
    </turbo-frame>
  <% end %>
</turbo-frame>

# Episode card with actions that remove it from inbox
<div class="episode-card">
  <h3><%= episode.title %></h3>
  <p>~<%= WhisperClient.estimate_cost_cents(episode.duration_seconds) %>¢ to process</p>

  <%= button_to "Add to Library",
      inbox_add_to_library_path(user_episode),
      data: { turbo_frame: dom_id(user_episode) } %>

  <%= button_to "Skip",
      inbox_skip_path(user_episode),
      data: { turbo_frame: dom_id(user_episode) } %>
</div>

# Episode detail view (Library/Archive)
<div class="episode-detail">
  <h1><%= @episode.title %></h1>

  <!-- Primary: AI Summary -->
  <section class="summary">
    <% @episode.summary.sections.each do |section| %>
      <h2><%= section['title'] %></h2>
      <p><%= section['content'] %></p>
    <% end %>

    <h2>Notable Quotes</h2>
    <% @episode.summary.quotes.each do |quote| %>
      <blockquote data-controller="audio-seek" data-time="<%= quote['start_time'] %>">
        "<%= quote['text'] %>"
      </blockquote>
    <% end %>
  </section>

  <!-- Collapsible: Original show notes from RSS -->
  <details>
    <summary>Original Show Notes</summary>
    <%= sanitize @episode.description %>
  </details>

  <!-- Secondary: Audio player -->
  <audio controls src="<%= @episode.audio_url %>"></audio>
</div>
```

### Turbo Streams for Processing Updates

```ruby
# In ProcessEpisodeJob, broadcast status updates:
user_episode.broadcast_replace_to(
  "library_#{user_episode.user_id}",
  target: dom_id(user_episode),
  partial: "user_episodes/library_card",
  locals: { user_episode: user_episode }
)
```

---

## Implementation Phases

### Phase 1: Core Loop (MVP)
Get the basic flow working end-to-end.

- [ ] Rails app setup (Rails 8, PostgreSQL, Solid Queue, Tailwind)
- [ ] Data models: User, Podcast, Subscription, Episode, UserEpisode, Transcript, Summary
- [ ] Podcast Index integration (search, fetch feed)
- [ ] Subscribe to podcast → episodes appear in Inbox
- [ ] Add to Library → triggers ProcessEpisodeJob
- [ ] Whisper integration (transcription)
- [ ] Claude integration (summarization)
- [ ] Episode detail view (summary + quotes)
- [ ] Basic audio player (play/pause/seek)

**Milestone**: Can subscribe to a podcast, add episode to library, read AI summary.

### Phase 2: Full Triage Flow
Complete the episode lifecycle.

- [ ] Skip to Trash
- [ ] Restore from Trash
- [ ] Archive (done) from Library
- [ ] Restore from Archive
- [ ] Trash auto-cleanup (90 days)
- [ ] Show Archive: browse any podcast's history
- [ ] Add to Inbox/Library from Show Archive
- [ ] Silent duplicate handling

**Milestone**: Full Inbox Zero workflow operational.

### Phase 3: Polish & Auth
Production-ready features.

- [ ] Magic link authentication
- [ ] Cost estimates before processing
- [ ] Processing status with detailed errors
- [ ] Regenerate summary
- [ ] OPML import
- [ ] Search across summaries
- [ ] Tap quote → jump to timestamp

**Milestone**: Fully usable personal app.

### Phase 4: PWA & Mobile
Better mobile experience.

- [ ] PWA manifest + service worker
- [ ] Responsive design pass
- [ ] Background audio (media session API)
- [ ] Add to home screen

---

## Environment Variables

Using environment variables for all configuration (no Rails credentials/master key).

```bash
# Heroku config vars

# Database (auto-set by Heroku)
DATABASE_URL=postgres://...

# Podcast Index (free at podcastindex.org)
PODCAST_INDEX_API_KEY=...
PODCAST_INDEX_API_SECRET=...

# OpenAI (for Whisper)
OPENAI_API_KEY=sk-...

# Anthropic (for Claude)
ANTHROPIC_API_KEY=sk-ant-...

# Email (for magic links)
SMTP_HOST=smtp.postmarkapp.com
SMTP_USERNAME=...
SMTP_PASSWORD=...
FROM_EMAIL=noreply@davepaola.com

# Rails
SECRET_KEY_BASE=...  # generate with `rails secret`
```

**Local development**: Use `.env` file with [dotenv-rails](https://github.com/bkeepers/dotenv) gem.

```ruby
# config/application.rb
# Remove credentials references, use ENV everywhere:
config.secret_key_base = ENV.fetch("SECRET_KEY_BASE")
```

---

## Cost Estimates

### API Costs (per episode)
| Service | Rate | 1hr episode |
|---------|------|-------------|
| Whisper | $0.006/min | $0.36 |
| Claude Sonnet | ~$3/M input + $15/M output | ~$0.05-0.15 |
| **Total** | | **~$0.45-0.55** |

### Heroku Costs (monthly)
| Resource | Cost |
|----------|------|
| Basic dyno (web) | $7 |
| Basic dyno (worker) | $7 |
| Postgres Mini | $5 |
| **Total** | **~$19/mo** |

### Estimated Monthly Total
Processing 10 episodes/week:
- API: ~$20/mo
- Heroku: ~$19/mo
- **Total: ~$39/mo**

---

## Search Implementation

Using PostgreSQL full-text search on summaries (simple, no external service).

```ruby
# Migration
class AddSearchableToSummaries < ActiveRecord::Migration[8.0]
  def up
    add_column :summaries, :searchable_text, :text
    add_column :summaries, :searchable, :tsvector
    add_index :summaries, :searchable, using: :gin

    # Trigger to auto-update tsvector when searchable_text changes
    execute <<-SQL
      CREATE TRIGGER summaries_searchable_update
      BEFORE INSERT OR UPDATE ON summaries
      FOR EACH ROW EXECUTE FUNCTION
      tsvector_update_trigger(searchable, 'pg_catalog.english', searchable_text);
    SQL
  end
end

# Model
class Summary < ApplicationRecord
  before_save :update_searchable_text

  scope :search, ->(query) {
    where("searchable @@ plainto_tsquery('english', ?)", query)
  }

  private

  # Extract text from jsonb sections for full-text search
  def update_searchable_text
    section_texts = sections.map { |s| "#{s['title']} #{s['content']}" }
    quote_texts = quotes.map { |q| q['text'] }
    self.searchable_text = (section_texts + quote_texts).join(" ")
  end
end

# Controller
def search
  @results = current_user.user_episodes
    .joins(episode: :summary)
    .merge(Summary.search(params[:q]))
    .where(location: [:library, :archive])
end
```

---

## iOS Future Considerations

Not implementing JSON API for v1, but keeping iOS port in mind:

| Consideration | Current State | Future Work |
|---------------|---------------|-------------|
| API endpoints | HTML only | Add `respond_to` JSON blocks when needed |
| Authentication | Magic links | Works for iOS (Safari → deep link back to app) |
| Shared backend | Yes | iOS app would be another client to same Rails API |
| Offline audio | Stream only | Would need download/cache feature for iOS |
| Push notifications | None | Add APNs integration in Phase 2+ |

**Recommendation**: When/if iOS becomes a priority, add JSON responses to existing controllers rather than building a separate API. The data model and business logic stay in Rails.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Whisper API rate limits | Queue with backoff, process overnight if needed |
| Long episode costs | Show cost estimate before processing (from RSS duration) |
| Podcast feeds malformed | Robust parser, graceful error handling |
| Audio URL expires | Fetch fresh URL from feed before playback |
| Processing job fails | Retry with exponential backoff, clear error messages |
| Multi-user cost sharing | First user to process pays; others get it free |

---

*Document version: 1.2*
*Last updated: 2025-01-25*
