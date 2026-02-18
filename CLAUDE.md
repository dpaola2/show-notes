# Claude Code Instructions

## Git Commit Policy

After completing each task:

1. **Run specs first** — `bundle exec rspec` must pass before committing
2. **Stage only the files related to that task** — use `git add <specific files>` rather than `git add .`
3. **Write a clear commit message** following this format:
   ```
   <type>: <short description>

   Task #<N>: <task subject>

   - Bullet points of what was done
   - Keep it concise but informative

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
   ```

4. **Commit types**:
   - `feat` — new feature or functionality
   - `chore` — setup, config, dependencies
   - `refactor` — code changes that don't add features
   - `fix` — bug fixes
   - `docs` — documentation only
   - `test` — adding or updating tests

5. **Example commit**:
   ```
   feat: add podcast and episode models

   Task #2: Create data models and migrations

   - Added User, Podcast, Subscription, Episode, UserEpisode models
   - Added Transcript and Summary models
   - Configured enums for location and processing_status
   - Added model specs

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
   ```

6. **Do not**:
   - Commit if specs are failing
   - Combine multiple tasks into one commit
   - Commit broken or incomplete work
   - Commit files unrelated to the current task

## Task Workflow

1. Mark task as `in_progress` before starting
2. Write failing specs first (where applicable)
3. Implement the feature
4. Ensure all specs pass: `bundle exec rspec`
5. Commit with message referencing the task
6. Mark task as `completed`
7. Move to next unblocked task

## Testing Strategy

### What to test:
- **Models**: Validations, associations, enums, scopes, instance methods
- **Services**: Core logic, API interactions (mocked), error handling
- **Jobs**: Job behavior, status updates, error handling
- **Requests**: Happy path, error cases, authentication (when added)

### What NOT to test:
- Views/templates
- System/browser tests
- Simple CRUD without business logic

### Test commands:
```bash
bundle exec rspec                    # Run all specs
bundle exec rspec spec/models        # Run model specs only
bundle exec rspec spec/requests      # Run request specs only
bundle exec rspec --format doc       # Verbose output
```

## Code Style

- Follow Rails conventions
- Use Tailwind utility classes for styling
- Keep controllers thin, models handle business logic
- Use service objects for external API integrations
- Write clear, self-documenting code

## Codebase Patterns & Gotchas

See also [AGENTS.md](AGENTS.md) for agent-discovered patterns and gotchas.

### Test Environment
- `show_exceptions = :none` — exceptions propagate as-is in tests (enables `raise_error(RecordNotFound)` in request specs)
- `sign_in_as(user)` stubs `current_user` via `allow_any_instance_of` — bypasses magic link flow for speed

### Authentication
- Magic link auth — `User.find_or_create_by!(email:)` in `SessionsController#create`
- `previously_new_record?` is cleared by `update!` — capture it in a local variable **before** calling any method that saves the record (e.g., `generate_magic_token!`)

### Mailers
- `ApplicationMailer` sends from `noreply@listen.davepaola.com`, uses `layout "mailer"`
- `UserMailer` — user-facing auth emails (magic links)
- `DigestMailer` — user-facing daily digest (newsletter format), includes `ApplicationHelper`
  - Uses class method + instance method architecture to work around ActionMailer's lazy `MessageDelivery` in Rails 8.1
  - `self.daily_digest(user)` eagerly queries episodes and creates EmailEvent tracking records, stores in `Thread.current[:digest_mailer_data]`
  - Instance method reads from thread-local (same-thread) or falls back to DB re-query (deliver_later in different thread)
  - Returns `ActionMailer::Base::NullMail.new` when no new episodes exist (skips sending)
- `SignupNotificationMailer` — internal admin notifications (separate class for different audience)
- All mailers use multipart templates (HTML + text) in `app/views/<mailer_name>/`
- Production: Resend (`config.action_mailer.delivery_method = :resend`)
- Development: Letter Opener (`config.action_mailer.delivery_method = :letter_opener`)
- Test: `:test` (accumulates in `ActionMailer::Base.deliveries`)

### Engagement Tracking
- `EmailEvent` model tracks digest email opens (pixel) and clicks (redirect links)
- Tracking endpoints (`TrackingController`) skip authentication — opaque tokens, internal destinations only
- `onboarding:engagement_report` rake task prints opens by user/date, clicks by episode, summary stats

### Background Jobs
- `SendDailyDigestJob` — library-scoped digest delivery, runs at 7 AM Eastern via Solid Queue
  - Overrides `perform_now` to suppress `ActiveJob::Base.logger` during execution (avoids LogSubscriber interference with test mocks)
- `FetchPodcastFeedJob` — fetches podcast RSS feeds, creates Episode + UserEpisode inbox entries for subscribers (no auto-transcription)
- `DetectStuckProcessingJob` — recurring (every 10 min), transitions UserEpisodes stuck in transcribing/summarizing >30 min to error
- `ProcessEpisodeJob` uses `limits_concurrency key: "transcription", to: 3` — Solid Queue semaphore limits global concurrent transcription jobs

## Autonomous Execution

When running autonomously:
1. Complete tasks in dependency order
2. If specs fail, fix the issue before proceeding
3. If stuck on a failing spec for more than 2 attempts, stop and report the issue
4. Commit after each task completes with passing specs

---

## Pipeline Configuration

> Pipeline skills read this section to understand how to run the agent pipeline against this repo.
> Run skills from this repo's root directory (not from the pipeline repo).

### Work Directory

| Setting | Path |
|---------|------|
| **Projects** | `docs/projects/` |
| **Inbox** | `docs/projects/inbox/` |

### Project Tracker

| Setting | Value |
|---------|-------|
| **Tool** | GitHub Issues |
| **Repository** | show-notes |

### Repository Details

| Setting | Value |
|---------|-------|
| **Default branch** | `main` |
| **Test command** | `bundle exec rspec` |
| **Test directory** | `spec/` |
| **Branch prefix** | `pipeline/` |
| **PR base branch** | `main` |

### Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Web (Rails) | Active | Single platform — web only |

### Framework & Stack

| Setting | Value |
|---------|-------|
| **Language** | Ruby 3.3 |
| **Framework** | Rails 8.1 |
| **Test framework** | RSpec |
| **ORM** | ActiveRecord |
| **Frontend JS** | Hotwire (Turbo + Stimulus) |
| **CSS** | Tailwind (via `tailwindcss-rails`) |
| **Asset pipeline** | Propshaft |
| **JS bundling** | Importmap (no Node/npm) |
| **Database (dev/test)** | SQLite3 |
| **Database (CI)** | PostgreSQL |
| **Background jobs** | Solid Queue (in-process, via Puma) |
| **Email (production)** | Resend |
| **Email (development)** | Letter Opener |
| **Deploy target** | Kamal (Docker) |

### Directory Structure

| Purpose | Path |
|---------|------|
| Models | `app/models/` |
| Controllers | `app/controllers/` |
| Views | `app/views/` |
| Services | `app/services/` |
| Helpers | `app/helpers/` |
| Mailers | `app/mailers/` |
| JavaScript controllers | `app/javascript/controllers/` |
| Background jobs | `app/jobs/` |
| Routes | `config/routes.rb` |
| Migrations | `db/migrate/` |
| Schema | `db/schema.rb` |
| Model specs | `spec/models/` |
| Request specs | `spec/requests/` |
| Service specs | `spec/services/` |
| Mailer specs | `spec/mailers/` |
| Job specs | `spec/jobs/` |
| Factories | `spec/factories/` |
| Support/helpers | `spec/support/` |
| Seed tasks | `lib/tasks/` |

### Implementation Order

1. Migration(s)
2. Model(s) — with validations, associations, scopes
3. Service(s) — business logic
4. Route(s)
5. Controller(s)
6. Views (ERB)
7. Stimulus controller(s)

### Post-Flight Checks

(OPTIONAL — linters, security scanners, and quality checks to run before opening a PR)

| Check | Command | Auto-fix? | Blocking? |
|-------|---------|-----------|-----------|
| **Ruby style** | `bin/rubocop -A` | Yes | Yes — commit fixes, re-run to confirm clean |
| **Security scan** | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | No | Yes — any findings block the PR |
| **Gem audit** | `bin/bundler-audit` | No | Yes — known vulnerabilities block the PR |
| **JS audit** | `bin/importmap audit` | No | Yes — known vulnerabilities block the PR |

> The `/create-pr` skill reads this table and runs each check on the project branch before pushing.
> Auto-fixable checks are run first; their fixes are committed. Then report-only checks run.
> If any blocking check fails after auto-fix, the skill stops and reports the findings.

### Guardrails

(REQUIRED — safety rules for agents)

| Guardrail | Rule |
|-----------|------|
| **Production access** | Agents NEVER have production access. No deploy credentials, no production database access. |
| **Default branch** | Never commit or merge directly to the default branch. |
| **Push** | Never push without explicit user request. |
| **Destructive operations** | No `drop_table`, `reset`, or data deletion without human approval. |
