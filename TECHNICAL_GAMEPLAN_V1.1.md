# Show Notes v1.1 — Technical Gameplan

This document outlines the implementation details for v1.1 features: cursor fix, clear inbox button, mobile responsive UI, and daily digest email.

---

## Task Breakdown

### Task 1: Button Cursor Fix
**Effort**: 30 minutes | **Risk**: Low

#### Changes

**File**: `app/assets/stylesheets/application.css`

Add global cursor styles:
```css
/* Ensure all interactive elements show pointer cursor */
button,
[type="button"],
[type="submit"],
[role="button"],
a.btn,
.cursor-pointer {
  cursor: pointer;
}
```

Alternatively, add to Tailwind config or use `cursor-pointer` class directly in templates.

#### Audit Checklist
- [ ] All `<button>` elements
- [ ] Form submit buttons
- [ ] Inbox episode rows (Add to Library / Skip)
- [ ] Library episode cards
- [ ] Navigation links styled as buttons
- [ ] Modal action buttons
- [ ] Audio player controls

#### Testing
- Manual browser testing across all views
- No automated tests needed

---

### Task 2: Clear Inbox Button
**Effort**: 1 hour | **Risk**: Low

#### Database Changes
None required — uses existing `location` enum and `trashed_at` timestamp.

#### Backend Changes

**File**: `config/routes.rb`
```ruby
# Add to existing inbox routes
resources :inbox, only: [:index] do
  collection do
    delete :clear
  end
end
```

**File**: `app/controllers/inbox_controller.rb`
```ruby
def clear
  count = current_user.user_episodes.in_inbox.count

  if count.zero?
    redirect_to inbox_path, alert: "Inbox is already empty"
    return
  end

  current_user.user_episodes.in_inbox.update_all(
    location: "trash",
    trashed_at: Time.current,
    updated_at: Time.current
  )

  redirect_to inbox_path, notice: "Cleared #{count} episode#{'s' unless count == 1} from inbox"
end
```

#### Frontend Changes

**File**: `app/views/inbox/index.html.erb`

Add button near inbox header:
```erb
<div class="flex items-center justify-between mb-4">
  <h1 class="text-2xl font-bold">Inbox (<%= @episodes.count %>)</h1>

  <% if @episodes.any? %>
    <%= button_to "Clear Inbox",
        clear_inbox_index_path,
        method: :delete,
        class: "btn btn-secondary text-sm",
        data: {
          turbo_confirm: "Skip all #{@episodes.count} episodes in your inbox?"
        } %>
  <% end %>
</div>
```

#### Testing

**File**: `spec/requests/inbox_spec.rb`
```ruby
describe "DELETE /inbox/clear" do
  it "moves all inbox episodes to trash" do
    user = create(:user)
    create_list(:user_episode, 3, user: user, location: :inbox)

    sign_in user
    expect {
      delete clear_inbox_index_path
    }.to change { user.user_episodes.in_inbox.count }.from(3).to(0)

    expect(user.user_episodes.in_trash.count).to eq(3)
  end

  it "redirects with success message" do
    user = create(:user)
    create_list(:user_episode, 5, user: user, location: :inbox)

    sign_in user
    delete clear_inbox_index_path

    expect(response).to redirect_to(inbox_path)
    follow_redirect!
    expect(response.body).to include("Cleared 5 episodes")
  end

  it "handles empty inbox gracefully" do
    user = create(:user)
    sign_in user

    delete clear_inbox_index_path

    expect(response).to redirect_to(inbox_path)
    follow_redirect!
    expect(response.body).to include("already empty")
  end
end
```

---

### Task 3: Mobile Responsive UI
**Effort**: 1-2 days | **Risk**: Medium

#### Approach
Use Tailwind's responsive prefixes (`sm:`, `md:`, `lg:`) to adapt layouts. Mobile-first approach: base styles for mobile, add complexity for larger screens.

#### View-by-View Changes

**1. Layout (`app/views/layouts/application.html.erb`)**

Ensure viewport meta tag exists:
```html
<meta name="viewport" content="width=device-width, initial-scale=1">
```

Navigation changes:
```erb
<!-- Mobile: bottom fixed nav -->
<nav class="fixed bottom-0 left-0 right-0 bg-white border-t md:hidden">
  <div class="flex justify-around py-2">
    <%= link_to inbox_path, class: "flex flex-col items-center p-2" do %>
      <!-- icon -->
      <span class="text-xs">Inbox</span>
    <% end %>
    <!-- ... other nav items -->
  </div>
</nav>

<!-- Desktop: top/side nav (existing) -->
<nav class="hidden md:block">
  <!-- existing navigation -->
</nav>

<!-- Add bottom padding on mobile for fixed nav -->
<main class="pb-20 md:pb-0">
  <%= yield %>
</main>
```

**2. Inbox View (`app/views/inbox/index.html.erb`)**

```erb
<!-- Episode card: stack on mobile, row on desktop -->
<div class="flex flex-col md:flex-row md:items-center gap-2 md:gap-4 p-4 border-b">
  <!-- Podcast artwork -->
  <div class="w-16 h-16 md:w-12 md:h-12 flex-shrink-0">
    <%= image_tag podcast.artwork_url, class: "rounded" %>
  </div>

  <!-- Episode info -->
  <div class="flex-grow min-w-0">
    <h3 class="font-medium truncate"><%= episode.title %></h3>
    <p class="text-sm text-gray-500 truncate"><%= episode.podcast.title %></p>
    <p class="text-xs text-gray-400 md:hidden"><%= episode.published_at.strftime("%b %d") %> • <%= episode.duration_human %></p>
  </div>

  <!-- Metadata (desktop only) -->
  <div class="hidden md:block text-sm text-gray-500 w-24">
    <%= episode.published_at.strftime("%b %d") %>
  </div>
  <div class="hidden md:block text-sm text-gray-500 w-16">
    <%= episode.duration_human %>
  </div>

  <!-- Actions: full width on mobile -->
  <div class="flex gap-2 mt-2 md:mt-0">
    <%= button_to "Add", ..., class: "flex-1 md:flex-none btn btn-primary py-3 md:py-2" %>
    <%= button_to "Skip", ..., class: "flex-1 md:flex-none btn btn-secondary py-3 md:py-2" %>
  </div>
</div>
```

**3. Library View (`app/views/library/index.html.erb`)**

Similar pattern — stack cards on mobile, grid on desktop:
```erb
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <% @episodes.each do |episode| %>
    <!-- Episode card -->
  <% end %>
</div>
```

**4. Episode Detail View (`app/views/episodes/show.html.erb`)**

Stack summary and audio on mobile:
```erb
<div class="flex flex-col lg:flex-row gap-6">
  <!-- Summary section -->
  <div class="flex-grow order-1">
    <!-- sections, quotes -->
  </div>

  <!-- Audio player: sticky on mobile -->
  <div class="lg:w-80 order-first lg:order-last">
    <div class="sticky top-0 lg:top-4 bg-white p-4 border rounded shadow-sm">
      <!-- audio controls -->
    </div>
  </div>
</div>
```

**5. Touch Targets**

Ensure minimum 44x44px for all interactive elements:
```css
/* Add to application.css or as Tailwind plugin */
@media (max-width: 768px) {
  button,
  [type="button"],
  a.btn {
    min-height: 44px;
    min-width: 44px;
  }
}
```

#### Testing
- Chrome DevTools device emulation
- Real device testing (iPhone, Android)
- Test at 375px, 414px, 768px, 1024px breakpoints
- No automated tests — visual verification

---

### Task 4: Daily Digest Email
**Effort**: 1 day | **Risk**: Medium

#### Database Changes

**Migration**: `db/migrate/XXXXXX_add_digest_fields_to_users.rb`
```ruby
class AddDigestFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :digest_enabled, :boolean, default: true, null: false
    add_column :users, :digest_sent_at, :datetime
  end
end
```

#### Model Changes

**File**: `app/models/user.rb`
```ruby
class User < ApplicationRecord
  # ... existing code ...

  scope :digest_subscribers, -> { where(digest_enabled: true) }

  def inbox_episodes_for_digest(limit: 5)
    user_episodes.in_inbox
                 .includes(episode: :podcast)
                 .order("episodes.published_at DESC")
                 .limit(limit)
  end

  def recent_library_episodes_for_digest(limit: 2)
    user_episodes.in_library
                 .where(processing_status: :ready)
                 .includes(episode: [:podcast, :summary])
                 .where("user_episodes.updated_at > ?", digest_sent_at || 1.week.ago)
                 .order("user_episodes.updated_at DESC")
                 .limit(limit)
  end

  def should_receive_digest?
    return false unless digest_enabled?

    inbox_episodes_for_digest.any? || recent_library_episodes_for_digest.any?
  end
end
```

#### Mailer

**File**: `app/mailers/digest_mailer.rb`
```ruby
class DigestMailer < ApplicationMailer
  def daily_digest(user)
    @user = user
    @inbox_episodes = user.inbox_episodes_for_digest
    @library_episodes = user.recent_library_episodes_for_digest
    @inbox_total = user.user_episodes.in_inbox.count

    mail(
      to: user.email,
      subject: "Your Daily Podcast Digest — #{Date.current.strftime('%b %-d')}"
    )
  end
end
```

**File**: `app/views/digest_mailer/daily_digest.html.erb`
```erb
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.5; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
    h1 { font-size: 24px; margin-bottom: 20px; }
    h2 { font-size: 18px; color: #666; border-bottom: 1px solid #eee; padding-bottom: 8px; margin-top: 30px; }
    .episode { margin-bottom: 20px; padding-bottom: 20px; border-bottom: 1px solid #f0f0f0; }
    .episode-title { font-weight: 600; font-size: 16px; }
    .podcast-name { color: #666; font-size: 14px; }
    .section { margin: 10px 0; padding-left: 15px; border-left: 3px solid #e0e0e0; }
    .section-title { font-weight: 600; font-size: 14px; }
    .section-content { font-size: 14px; color: #555; }
    .quote { background: #f9f9f9; padding: 10px; margin: 10px 0; border-radius: 4px; font-style: italic; }
    .quote-time { font-size: 12px; color: #888; font-style: normal; }
    .btn { display: inline-block; padding: 10px 20px; background: #2563eb; color: white; text-decoration: none; border-radius: 6px; margin-top: 10px; }
    .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; font-size: 12px; color: #888; }
  </style>
</head>
<body>
  <h1>Good morning!</h1>

  <% if @inbox_episodes.any? %>
    <h2>📥 Inbox (<%= @inbox_total %> episodes)</h2>
    <% @inbox_episodes.each do |ue| %>
      <div class="episode">
        <div class="podcast-name"><%= ue.episode.podcast.title %></div>
        <div class="episode-title"><%= ue.episode.title %></div>
      </div>
    <% end %>
    <% if @inbox_total > @inbox_episodes.count %>
      <p style="color: #666; font-size: 14px;">+ <%= @inbox_total - @inbox_episodes.count %> more</p>
    <% end %>
    <a href="<%= inbox_url %>" class="btn">Open Inbox</a>
  <% end %>

  <% if @library_episodes.any? %>
    <h2>📚 Recently Ready</h2>
    <% @library_episodes.each do |ue| %>
      <div class="episode">
        <div class="podcast-name"><%= ue.episode.podcast.title %></div>
        <div class="episode-title"><%= ue.episode.title %></div>
        <p style="font-size: 13px; color: #888;"><%= ue.episode.duration_human %> • Ready <%= time_ago_in_words(ue.updated_at) %> ago</p>

        <% if ue.episode.summary %>
          <h4 style="font-size: 14px; margin: 15px 0 10px;">Sections:</h4>
          <% ue.episode.summary.sections.first(3).each do |section| %>
            <div class="section">
              <div class="section-title"><%= section["title"] %></div>
              <div class="section-content"><%= truncate(section["content"], length: 150) %></div>
            </div>
          <% end %>

          <% if ue.episode.summary.quotes.any? %>
            <h4 style="font-size: 14px; margin: 15px 0 10px;">Notable Quotes:</h4>
            <% ue.episode.summary.quotes.first(2).each do |quote| %>
              <div class="quote">
                "<%= quote["text"] %>"
                <span class="quote-time">(<%= format_timestamp(quote["start_time"]) %>)</span>
              </div>
            <% end %>
          <% end %>
        <% end %>

        <a href="<%= episode_url(ue.episode) %>" class="btn">Read Full Summary</a>
      </div>
    <% end %>
  <% end %>

  <div class="footer">
    <p>You're receiving this because you have daily digests enabled.</p>
    <p><a href="<%= settings_url %>">Manage digest settings</a> | <a href="<%= unsubscribe_digest_url(token: @user.digest_unsubscribe_token) %>">Unsubscribe</a></p>
  </div>
</body>
</html>
```

**File**: `app/views/digest_mailer/daily_digest.text.erb`
```erb
Good morning!

<% if @inbox_episodes.any? %>
=====================================
📥 INBOX (<%= @inbox_total %> episodes)
=====================================

<% @inbox_episodes.each do |ue| %>
• <%= ue.episode.podcast.title %> — "<%= ue.episode.title %>"
<% end %>
<% if @inbox_total > @inbox_episodes.count %>
+ <%= @inbox_total - @inbox_episodes.count %> more
<% end %>

→ Open Inbox: <%= inbox_url %>

<% end %>
<% if @library_episodes.any? %>
=====================================
📚 RECENTLY READY
=====================================

<% @library_episodes.each do |ue| %>
<%= ue.episode.podcast.title.upcase %> — "<%= ue.episode.title %>"
<%= ue.episode.duration_human %> • Ready <%= time_ago_in_words(ue.updated_at) %> ago

<% if ue.episode.summary %>
Sections:
<% ue.episode.summary.sections.first(3).each_with_index do |section, i| %>
<%= i + 1 %>. <%= section["title"] %>
   <%= truncate(section["content"], length: 150) %>
<% end %>

<% if ue.episode.summary.quotes.any? %>
Notable Quotes:
<% ue.episode.summary.quotes.first(2).each do |quote| %>
• "<%= quote["text"] %>" (<%= format_timestamp(quote["start_time"]) %>)
<% end %>
<% end %>
<% end %>

→ Read full summary: <%= episode_url(ue.episode) %>

---

<% end %>
<% end %>
=====================================

Manage digest settings: <%= settings_url %>
Unsubscribe: <%= unsubscribe_digest_url(token: @user.digest_unsubscribe_token) %>
```

#### Background Job

**File**: `app/jobs/send_daily_digest_job.rb`
```ruby
class SendDailyDigestJob < ApplicationJob
  queue_as :default

  def perform
    User.digest_subscribers.find_each do |user|
      next unless user.should_receive_digest?

      DigestMailer.daily_digest(user).deliver_later
      user.update!(digest_sent_at: Time.current)
    rescue => e
      Rails.logger.error "Failed to send digest to user #{user.id}: #{e.message}"
    end
  end
end
```

#### Recurring Schedule

**File**: `config/recurring.yml`
```yaml
# Add to existing recurring tasks
send_daily_digest:
  class: SendDailyDigestJob
  schedule: "0 7 * * *"  # 7:00 AM UTC daily
  description: "Send daily digest emails to subscribed users"
```

#### Helper for Timestamp Formatting

**File**: `app/helpers/application_helper.rb`
```ruby
def format_timestamp(seconds)
  return "0:00" unless seconds

  mins = (seconds / 60).to_i
  secs = (seconds % 60).to_i
  "#{mins}:#{secs.to_s.rjust(2, '0')}"
end
```

#### Settings UI

**File**: `app/views/settings/index.html.erb`
```erb
<h2>Email Preferences</h2>

<%= form_with model: current_user, url: settings_path, method: :patch do |f| %>
  <div class="flex items-center gap-3">
    <%= f.check_box :digest_enabled, class: "h-5 w-5" %>
    <%= f.label :digest_enabled, "Send me a daily digest at 7:00 AM UTC" %>
  </div>

  <%= f.submit "Save", class: "btn btn-primary mt-4" %>
<% end %>
```

#### Routes

**File**: `config/routes.rb`
```ruby
# Add unsubscribe route
get "digest/unsubscribe", to: "digest#unsubscribe", as: :unsubscribe_digest
```

#### Testing

**File**: `spec/mailers/digest_mailer_spec.rb`
```ruby
require "rails_helper"

RSpec.describe DigestMailer, type: :mailer do
  describe "#daily_digest" do
    let(:user) { create(:user) }
    let!(:inbox_episode) { create(:user_episode, user: user, location: :inbox) }
    let!(:library_episode) { create(:user_episode, :with_summary, user: user, location: :library, processing_status: :ready) }

    it "renders the headers" do
      mail = DigestMailer.daily_digest(user)

      expect(mail.subject).to include("Daily Podcast Digest")
      expect(mail.to).to eq([user.email])
    end

    it "includes inbox episodes" do
      mail = DigestMailer.daily_digest(user)

      expect(mail.body.encoded).to include(inbox_episode.episode.title)
    end

    it "includes library summaries" do
      mail = DigestMailer.daily_digest(user)

      expect(mail.body.encoded).to include(library_episode.episode.title)
      expect(mail.body.encoded).to include(library_episode.episode.summary.sections.first["title"])
    end
  end
end
```

**File**: `spec/jobs/send_daily_digest_job_spec.rb`
```ruby
require "rails_helper"

RSpec.describe SendDailyDigestJob, type: :job do
  it "sends digest to users with digest_enabled" do
    user = create(:user, digest_enabled: true)
    create(:user_episode, user: user, location: :inbox)

    expect {
      described_class.perform_now
    }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
  end

  it "skips users with digest_enabled: false" do
    user = create(:user, digest_enabled: false)
    create(:user_episode, user: user, location: :inbox)

    expect {
      described_class.perform_now
    }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
  end

  it "skips users with empty inbox and no recent library items" do
    user = create(:user, digest_enabled: true)
    # no episodes

    expect {
      described_class.perform_now
    }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
  end

  it "updates digest_sent_at after sending" do
    user = create(:user, digest_enabled: true, digest_sent_at: nil)
    create(:user_episode, user: user, location: :inbox)

    freeze_time do
      described_class.perform_now
      expect(user.reload.digest_sent_at).to eq(Time.current)
    end
  end
end
```

---

## Implementation Order

| Order | Task | Dependencies | Commit After |
|-------|------|--------------|--------------|
| 1 | Cursor fix | None | Yes |
| 2 | Clear inbox button | None | Yes |
| 3 | Mobile responsive - Layout | None | Yes |
| 4 | Mobile responsive - Inbox | Task 3 | Yes |
| 5 | Mobile responsive - Library | Task 3 | Yes |
| 6 | Mobile responsive - Episode detail | Task 3 | Yes |
| 7 | Daily digest - Migration | None | Yes |
| 8 | Daily digest - Mailer | Task 7 | Yes |
| 9 | Daily digest - Job + Schedule | Task 8 | Yes |
| 10 | Daily digest - Settings UI | Task 7 | Yes |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Clear inbox accidental click | Confirmation dialog with count |
| Mobile layout breaks desktop | Use responsive prefixes only, test both |
| Digest spam | Only send if new content, include unsubscribe |
| Digest email delivery | Monitor Resend dashboard, add error logging |
| Timezone confusion | Document that 7 AM is UTC, add user timezone later |

---

## Rollback Plan

- **Cursor fix**: Revert CSS change
- **Clear inbox**: Remove route, no data impact
- **Mobile responsive**: Revert view changes, no data impact
- **Daily digest**: Set `digest_enabled: false` for all users, disable recurring job

---

*Document version: 1.0*
*Created: 2026-01-25*
