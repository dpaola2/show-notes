# Agent-Discovered Patterns & Gotchas

Hard-won lessons from debugging sessions. Check here before implementing similar features.

## Turbo Drive & Form Submissions

Turbo Drive intercepts all `<form>` submissions and enforces strict response rules:

- **Redirects (3xx)** — required for successful form submissions (use `redirect_to`)
- **422 Unprocessable Entity** — accepted for validation errors (re-renders the form)
- **200 OK with HTML body** — **rejected** with `Form responses must redirect to another location`

**Never `render` a template from a POST action.** Use the PRG (Post/Redirect/Get) pattern instead:

```ruby
# Bad — Turbo will reject this
def create
  @result = SomeService.call(params)
  render :next_step  # 200 OK — Turbo error
end

# Good — redirect to a GET action
def create
  result = SomeService.call(params)
  session[:result_data] = result.summary
  redirect_to next_step_path
end

def next_step
  @data = session.delete(:result_data)
end
```

### Session Serialization Caveat

When storing hashes in the session, symbol keys become strings after the JSON round-trip:

```ruby
# In the controller
session[:import_failed] = [{ feed_url: "https://...", error: "..." }]

# After redirect — keys are now strings
session[:import_failed].first["feed_url"]  # correct
session[:import_failed].first[:feed_url]   # nil
```

## Scoped Uniqueness Validations

Always scope uniqueness validations to the parent record when a child's identifier is only unique within its parent. Keep the model validation and database index in sync.

**Example:** Episode GUIDs are unique per podcast, not globally.

```ruby
# Model — scope the validation
validates :guid, presence: true, uniqueness: { scope: :podcast_id }

# Migration — composite unique index must match
remove_index :episodes, :guid, unique: true
add_index :episodes, [:podcast_id, :guid], unique: true
```

**Query pattern:** Always look up through the association, not globally:

```ruby
# Bad — finds any episode with this guid, possibly from the wrong podcast
Episode.find_or_initialize_by(guid: episode_data.guid)

# Good — scoped to the correct podcast
podcast.episodes.find_or_initialize_by(guid: episode_data.guid)
```

### Composite Index Column Order

`[podcast_id, guid]` means the index is also usable for queries filtered by `podcast_id` alone (like `podcast.episodes`), but *not* for queries filtered by `guid` alone. Put the scoping column first.

## State Machine Completeness

When modeling stateful workflows (e.g., background job processing), ensure every transitional state has an exit path for **both** success and failure. A state like `transcribing` that only transitions on success becomes a dead end when errors occur — the record gets stuck permanently with no recovery path.

**Checklist for transitional states:**

1. **Error transition** — What state does the record move to when the operation fails?
2. **Error capture** — Is the failure reason stored so users can understand what happened?
3. **Recovery action** — Can the user (or system) retry from the error state?
4. **Timeout detection** — If the job silently dies, how is the stuck record detected?
5. **Idempotency** — If retry is triggered multiple times, does only one job run?

```ruby
# Bad — only handles success
after_perform { episode.update!(status: "transcribed") }

# Good — handles both outcomes
def perform(episode)
  result = TranscriptionService.call(episode)
  episode.update!(status: "transcribed", transcript: result)
rescue TranscriptionService::RateLimitError => e
  episode.update!(status: "transcription_failed", error_message: e.message)
rescue => e
  episode.update!(status: "transcription_failed", error_message: "Unexpected error: #{e.message}")
end
```

## Active Storage URL Generation in Models

`rails_blob_url` requires a host. When calling from a model (no request context), provide a fallback:

```ruby
def og_image_url
  return nil unless og_image.attached?
  host = Rails.application.routes.default_url_options[:host] || ENV.fetch("APP_HOST", "localhost:3000")
  Rails.application.routes.url_helpers.rails_blob_url(og_image, host: host)
end
```

## Public (Unauthenticated) Controllers

Three controllers skip authentication: `SessionsController` (login flow, uses `sessions` layout), `TrackingController` (email tracking, no layout), and `PublicEpisodesController` (public episode pages, uses `public` layout). All use `skip_before_action :require_authentication`. Public controllers should NOT reference `current_user` except optionally (e.g., associating share events with logged-in users).

## Production Server Operations

SSH into the server first:

```bash
ssh deploy@147.182.181.10
```

### Tailing Logs

```bash
# Rails server logs
journalctl --user --unit=show-notes-server --follow

# Solid Queue worker logs
journalctl --user --unit=show-notes-solid_queue --follow
```

### Rails Console

```bash
cd ~/show-notes/current && bundle exec rails c
```
