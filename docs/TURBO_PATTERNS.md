# Turbo Frames and Streams Patterns

This documents how we use Hotwire's Turbo in this application.

## The "Content Missing" Problem

When a `button_to` or `link_to` is inside a `turbo_frame_tag`, Turbo expects the response to contain a matching frame. If the controller redirects to a page without that frame, you get **"Content missing"**.

### Bad: Button inside frame with redirect

```erb
<%= turbo_frame_tag "search_results" do %>
  <%= button_to "Subscribe", podcasts_path %>  <!-- Redirects to /subscriptions -->
<% end %>
```

The redirect goes to `/subscriptions` which doesn't have a `search_results` frame → "Content missing".

### Fix 1: Break out of the frame

```erb
<%= button_to "Subscribe", podcasts_path, data: { turbo_frame: "_top" } %>
```

`_top` tells Turbo to do a full page navigation instead of looking for a frame.

### Fix 2: Don't use a frame

If buttons inside a container all redirect to other pages, don't wrap it in a turbo frame.

### Fix 3: Use Turbo Streams (proper solution)

Have the controller return a Turbo Stream response that removes/updates the specific frame:

```ruby
# Controller
def destroy
  @item.destroy
  respond_to do |format|
    format.turbo_stream { render turbo_stream: turbo_stream.remove(@item) }
    format.html { redirect_to items_path }
  end
end
```

## Current Usage

### Podcast Search (`podcasts/index.html.erb`)

**Uses Turbo Frame correctly.** The search form targets `search_results`, and the GET request returns content for that frame. The Subscribe button breaks out with `turbo_frame: "_top"`.

### Inbox (`inbox/index.html.erb`)

**No longer uses Turbo Frames.** Previously wrapped each episode in a frame, but since controllers do redirects (not Turbo Stream responses), frames caused issues. Removed frames until we implement proper Turbo Streams.

## Future: Turbo Streams for Real-Time Updates

When we implement real-time processing status updates (Phase 1 item), we should:

1. Wrap Library items in turbo frames with `dom_id(@user_episode)`
2. Have `ProcessEpisodeJob` broadcast Turbo Stream updates
3. Subscribe to updates via `turbo_stream_from` in the view

Example:
```erb
<%= turbo_stream_from current_user, "episodes" %>

<%= turbo_frame_tag dom_id(user_episode) do %>
  <!-- episode content -->
<% end %>
```

```ruby
# In ProcessEpisodeJob
Turbo::StreamsChannel.broadcast_replace_to(
  [user_episode.user, "episodes"],
  target: dom_id(user_episode),
  partial: "library/episode",
  locals: { user_episode: user_episode }
)
```

## Rules of Thumb

1. **Forms that update in-place** → Use Turbo Frames (like search)
2. **Buttons that redirect elsewhere** → Add `data: { turbo_frame: "_top" }`
3. **Lists where items get removed/updated** → Use Turbo Streams (not just frames)
4. **When in doubt** → Skip frames, use regular page navigation
