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

## Engineering Methodology

These conventions apply to every change in this codebase — features, bug fixes, refactors. Future agents and human engineers should follow them by default. Mirrored from the canonical template at `~/projects/assistant/03-living-docs/Engineering-Methodology.md` — update there first, then sync.

### 1. Always work from a plan, not vibes

Before writing code, produce (or read) two artifacts:

- **Requirements** — what behavior is expected, in plain language. Inputs, outputs, edge cases.
- **Technical gameplan** — how you'll achieve those requirements. Files to touch, data model changes, test strategy, rollback.

For trivial fixes the plan can be three bullets. For anything else, write it down. The plan is what we align on; the code is the consequence.

### 2. TDD by default — Red → Green → Refactor

Write a failing test first. Watch it fail. Write the minimum code to make it pass. Then refactor with the test as your safety net. Applies to:

- **New features** — the test specifies what "done" means before you start.
- **Bug fixes** — the test reproduces the bug and stays in the suite as a regression guard. **A bug fix without a regression test is not done.** Even a one-character fix gets a test that would have caught it.
- **Refactors** — existing tests must continue to pass; add new ones if you discover untested behavior in the area you're touching.

### 3. Test behavior, not implementation

Tests should describe **what** the system does, not **how** it does it.

- **Test the public interface.** Assert on return values and observable side effects of public methods. Don't test private methods directly — they're tested through the public interface.
- **Don't test what you don't own.** Don't assert that Rails, the database, or third-party gems work. Test that *your code* sends the right messages to them.
- **Incoming messages → assert result.** Public methods return values or cause side effects; assert those.
- **Outgoing command messages → assert sent.** When your object tells a collaborator to *do* something (create a record, send an email), assert the message was sent — not what happens inside the collaborator.
- **Outgoing query messages → don't test.** If your object asks a collaborator a question, don't assert that the question was asked. That's an implementation detail.
- **Mocks belong at boundaries** (HTTP, jobs, external APIs), not inside your own object graph.
- **Structural assertions are an anti-pattern.** Don't test file layout, line counts, or directory structure. If the public contract works, the structure is irrelevant.
- **A test that breaks when you refactor without changing behavior is testing the wrong thing.** Delete it or rewrite it.

### 4. Sandi Metz rules — guardrails, not laws

- **Classes ≤ 100 lines.** If a class exceeds 100 LOC, it's doing too much — extract a new object.
- **Methods ≤ 5 lines** (aspirational — use judgment). Long methods hide multiple responsibilities.
- **≤ 4 parameters per method.** More than 4 means you need a parameter object or the method is doing too much. Use keyword args.
- **Controllers instantiate one object.** The controller action creates/finds one primary object; logic lives in that object or its collaborators, not in the controller.

Break a rule when you have a good reason; document the reason. The point is to push you toward extraction when something is growing — not to mechanically count lines.

### 5. SOLID, briefly

- **Single Responsibility** — each class has one reason to change. Can't name it without "and"? Extract.
- **Open/Closed** — extend by adding new classes (services, executors, strategies), not by editing existing ones.
- **Liskov Substitution** — subclasses should be drop-in replaceable for their parents; the caller shouldn't need to know.
- **Interface Segregation** — clients depend only on what they use; don't fatten interfaces to satisfy unrelated callers.
- **Dependency Inversion** — depend on abstractions (duck-typed collaborators), not concretions. Inject collaborators so tests can substitute fakes without mocking frameworks.

### 6. In practice

- **Small objects > large objects.** When in doubt, extract a new class. A 30-line class with a clear name is better than a private method buried in a 300-line file.
- **Composition over inheritance.** Use modules for shared behavior; prefer injecting collaborators over deep inheritance hierarchies.
- **Tell, don't ask.** Send messages to objects rather than querying their state and making decisions for them.
- **Trust the message.** If you find yourself checking an object's type or state to decide what to do, push that decision into the object itself.
- **Objects play roles, not identities.** Design around *what messages an object responds to* (its role), not *what class it is* (its identity). Duck typing makes code open to extension: new objects can play existing roles without modifying callers.

---

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
  - Library-drip signature: `self.daily_digest(user, since: nil, featured_episode_id: nil, recent_episode_ids: nil)`. `since:` is a no-op kwarg retained for backwards compat with older serialised Solid Queue jobs (per SN-17 GP-1); will be removed in a follow-up release.
  - `self.daily_digest(user, ...)` eagerly picks featured + 5 compact episodes (by passed IDs OR via `Episode.eligible_for_drip(user).limit(6)`), creates EmailEvent tracking records, AND stamps `digest_featured_at` / `digest_last_appeared_at` — all wrapped in a single `ActiveRecord::Base.transaction` so a failure inside event creation rolls back the digest-stamping (TRK-004 atomicity).
  - Instance method reads from `Thread.current[:digest_mailer_data]` (same-thread) or falls back to loading episodes by `featured_episode_id` / `recent_episode_ids` kwargs (deliver_later in different thread); fallback to fresh `eligible_for_drip` re-query only when both kwarg IDs are nil (legacy queue draining).
  - Returns `ActionMailer::Base::NullMail.new` when no eligible episodes exist (skips sending; no EmailEvents created).
- `SignupNotificationMailer` — internal admin notifications (separate class for different audience)
- All mailers use multipart templates (HTML + text) in `app/views/<mailer_name>/`
- Production: Resend (`config.action_mailer.delivery_method = :resend`)
- Development: Letter Opener (`config.action_mailer.delivery_method = :letter_opener`)
- Test: `:test` (accumulates in `ActionMailer::Base.deliveries`)

### Engagement Tracking
- `EmailEvent` model tracks digest email opens (pixel) and clicks (redirect links)
- Tracking endpoints (`TrackingController`) skip authentication — opaque tokens, internal destinations only
- `onboarding:engagement_report` rake task prints opens by user/date, clicks by episode, summary stats

### ActiveRecord Scopes
- Prefer `.preload` over `.includes` for scopes that need eager-loaded associations without filter/order on the joined tables. `.includes` + `.joins` of the same association makes `eager_loading?` true, which causes `Relation#exists?` to internally re-spawn the relation via `apply_join_dependency`. Combined with `clone`-based spawning, RSpec's `allow(rel).to receive(:exists?).and_call_original` recurses infinitely on the cloned singleton stub. `.preload` issues separate queries and avoids the eager-loading branch entirely.
- `Episode.eligible_for_drip(user)` (library-drip selector) is the canonical example — joins on `:user_episodes, :podcast, :summary` for filtering + preloads `:podcast, :summary` for view-time access.
- Use `Arel.sql("...")` inside `.order(...)` for raw SQL clauses like `published_at DESC NULLS LAST` — Rails 8.1 enforces this for non-attribute order fragments to prevent SQL injection.

### Background Jobs
- `SendDailyDigestJob` — library-drip digest delivery, runs at 7 AM Eastern via Solid Queue
  - Overrides `perform_now` to suppress `ActiveJob::Base.logger` during execution (avoids LogSubscriber interference with test mocks)
  - Per-user loop: calls `Episode.eligible_for_drip(user)` once, uses `.exists?` for the predicate, then materializes `.limit(6).to_a` to pass featured + recent episode IDs as kwargs to `DigestMailer.daily_digest(user, ...)`. This keeps `eligible_for_drip` to a single call per user iteration (the mailer trusts the IDs and does not re-query), which makes the deliver_later worker fully deterministic.
  - `digest_sent_at` is bumped on every successful enqueue (retained for `settings#show`); NOT bumped when a user has zero eligible episodes (no enqueue).
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
| **Production access** | Agents MAY SSH read-only to tail logs (`journalctl --user --unit=show-notes-server` / `--unit=show-notes-solid_queue`, including `--since`/`--until`/`--follow` and grep filters). Anything beyond log reads — Rails console (even reads), production database access, `systemctl` restarts, deploys, file writes, destructive commands — requires explicit per-session Dave approval. No deploy credentials. |
| **Default branch** | Never commit or merge directly to the default branch. |
| **Push** | Never push without explicit user request. |
| **Destructive operations** | No `drop_table`, `reset`, or data deletion without human approval. |
