# Plan: Add Pagination to Inbox and Library

## Current State

Both `InboxController#index` and `LibraryController#index` load all matching records with no limit. With 5,135 episodes already in the system, this will get slow as the inbox/library grows.

No pagination gem is currently installed.

## Approach: Pagy

Use [pagy](https://github.com/ddnexus/pagy) — the fastest and most lightweight Rails pagination gem. It's the standard choice for Rails 8 apps (kaminari and will_paginate are heavier and less maintained).

Pagy works by wrapping any ActiveRecord scope with `pagy()` which returns a metadata object and a paginated scope. No model changes needed.

## Step 1: Add pagy gem

**File: `Gemfile`**
```ruby
gem "pagy"
```

Run `bundle install`.

## Step 2: Configure pagy

**File: `config/initializers/pagy.rb`**
```ruby
Pagy::DEFAULT[:limit] = 20
```

20 items per page is a good default — enough to scroll through without overwhelming, and matches the card-based layout.

## Step 3: Include pagy in controllers

**File: `app/controllers/application_controller.rb`**
- Add `include Pagy::Backend`

**File: `app/helpers/application_helper.rb`**
- Add `include Pagy::Frontend`

## Step 4: Paginate inbox

**File: `app/controllers/inbox_controller.rb`**
Change `index` to:
```ruby
def index
  @pagy, @user_episodes = pagy(
    current_user.user_episodes
      .in_inbox
      .includes(episode: :podcast)
      .order("episodes.published_at DESC")
  )
end
```

**File: `app/views/inbox/index.html.erb`**
- Update count in header to use `@pagy.count` (total across all pages) instead of `@user_episodes.count`
- Add pagination nav after the episode list: `<%== pagy_nav(@pagy) %>`

## Step 5: Paginate library

**File: `app/controllers/library_controller.rb`**
Same pattern — wrap the query with `pagy()`.

**File: `app/views/library/index.html.erb`**
- Add pagination nav after the episode list

## Step 6: Style pagination for Tailwind

Pagy has built-in Tailwind support via `pagy_nav_js` or CSS classes. Use `pagy_nav(@pagy)` with a Tailwind-styled helper, or use pagy's bundled Tailwind extra.

## Step 7: Add specs

- Test that inbox#index paginates (returns limited records, includes pagination metadata)
- Test that library#index paginates
- Test page parameter handling (page 1, page 2, out-of-range page)

## Files Changed

| File | Change |
|------|--------|
| `Gemfile` | Add `pagy` |
| `config/initializers/pagy.rb` | New — default config |
| `app/controllers/application_controller.rb` | Include `Pagy::Backend` |
| `app/helpers/application_helper.rb` | Include `Pagy::Frontend` |
| `app/controllers/inbox_controller.rb` | Wrap query with `pagy()` |
| `app/controllers/library_controller.rb` | Wrap query with `pagy()` |
| `app/views/inbox/index.html.erb` | Add pagination nav, fix count |
| `app/views/library/index.html.erb` | Add pagination nav |
| `spec/requests/inbox_spec.rb` | Add pagination specs |
| `spec/requests/library_spec.rb` | Add pagination specs |
