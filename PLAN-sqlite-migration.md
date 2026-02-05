# Plan: Migrate from PostgreSQL to SQLite

## Current State

- **Database**: PostgreSQL via `pg` gem
- **PostgreSQL-specific features in use**:
  - `jsonb` columns on `summaries` table (`sections`, `quotes`) — used only as Ruby hashes/arrays, no PG JSON operators in queries
  - `enable_extension "pg_catalog.plpgsql"` — not needed for SQLite
  - `bigint` foreign keys — SQLite uses integer primary keys natively
- **Solid Queue/Cache/Cable**: All configured for production; these work natively with SQLite (that's actually their default)
- **Data dump**: `latest.dump` is a PostgreSQL custom-format dump (7 MB)
- **App tables with data to migrate**: `users`, `podcasts`, `episodes`, `transcripts`, `summaries`, `subscriptions`, `user_episodes`
- **Solid tables to skip**: `solid_queue_*`, `solid_cache_*`, `solid_cable_*` (transient/operational data)

---

## Step 1: Swap gems

**File: `Gemfile`**
- Remove `gem "pg", "~> 1.1"`
- Add `gem "sqlite3"`
- Run `bundle install`

## Step 2: Update database.yml

**File: `config/database.yml`**
```yaml
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  <<: *default
  database: storage/development.sqlite3

test:
  <<: *default
  database: storage/test.sqlite3

production:
  <<: *default
  database: storage/production.sqlite3
```

Using `storage/` directory is the Rails 8 convention for SQLite databases on deployment platforms like Hatchbox (the `storage/` dir persists across deploys).

## Step 3: Handle jsonb → json migration

**File: `db/migrate/[timestamp]_change_jsonb_to_json.rb`**

Create a migration that changes the `summaries` table's `jsonb` columns to `json`. In SQLite, both map to TEXT storage internally, but using `json` is the correct column type for SQLite compatibility.

Alternatively, we may just regenerate the schema since we're rebuilding from scratch.

## Step 4: Regenerate schema and verify

```bash
bin/rails db:create
bin/rails db:schema:load   # Load existing schema (after updating jsonb→json)
bin/rails db:migrate        # Apply any new migration
```

Verify that schema.rb is regenerated cleanly without PostgreSQL-specific extensions.

## Step 5: Create data conversion script

**File: `bin/pg_to_sqlite`**

A Ruby script that:
1. Restores `latest.dump` into a temporary PostgreSQL database (`show_notes_migration_tmp`)
2. Connects to both the temp PG database and the new SQLite database
3. Copies rows from these application tables:
   - `users`
   - `podcasts`
   - `episodes`
   - `transcripts`
   - `summaries`
   - `subscriptions`
   - `user_episodes`
4. Preserves primary key IDs so foreign keys remain valid
5. Resets SQLite autoincrement sequences
6. Drops the temporary PostgreSQL database when done

**Why this approach?** The dump is in PostgreSQL custom format (not plain SQL), so we can't just text-transform it. Restoring to a temp PG database and reading rows through ActiveRecord/Sequel is the most reliable way to handle type coercion (especially jsonb → json).

**Prerequisite**: PostgreSQL must still be installed locally to run `pg_restore` for the one-time migration. After migration, PG is no longer needed.

## Step 6: Run specs

```bash
bundle exec rspec
```

Fix any failures related to:
- PostgreSQL-specific query syntax (none found, but verify)
- jsonb vs json behavior differences (minimal — Ruby serializes identically)
- Test database setup

## Step 7: Update .gitignore

- Add `storage/*.sqlite3` (don't commit database files)
- Remove any PG-specific ignores if present

## Step 8: Clean up

- Remove `latest.dump` from repo (or keep for reference, but it won't be needed after migration)
- Update any deploy/Hatchbox config notes

---

## Risks & Notes

| Risk | Mitigation |
|------|-----------|
| `jsonb` columns in summaries | App only uses Ruby hash/array access, no PG JSON operators — low risk |
| SQLite concurrent writes | Solid Queue uses WAL mode by default; Hatchbox runs single-server, so this is fine |
| Sequence/ID gaps | Script preserves original IDs; SQLite autoincrement handles new records |
| Large transcripts as TEXT | SQLite handles large TEXT fields well; no size concern at 7 MB total |

## Order of Execution

1. Step 1 (gems) + Step 2 (database.yml) — can be done together
2. Step 3 (migration) + Step 4 (schema)
3. Step 7 (.gitignore)
4. Step 6 (specs) — verify everything works
5. Step 5 (conversion script) — can be built and tested independently
6. Step 8 (cleanup)
