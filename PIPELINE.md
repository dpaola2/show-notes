# Pipeline Configuration

> Repo-specific settings that the agent pipeline reads to understand this codebase.
> This file describes HOW this repo works — framework, directory structure, test commands, conventions.
> The pipeline repo's `pipeline.md` tells the pipeline WHERE this repo is.
>
> Sections marked REQUIRED apply to every project using the pipeline.
> Sections marked OPTIONAL can be omitted entirely if they don't apply.

---

## Repository Details

(REQUIRED — branch and test config)

| Setting | Value |
|---------|-------|
| **Default branch** | `main` |
| **Conventions file** | `CLAUDE.md` (repo root) |
| **Test command** | `bundle exec rspec` |
| **Test directory** | `spec/` |
| **Branch prefix** | `pipeline/` |
| **PR base branch** | `main` |

---

## Platforms

(REQUIRED — which platforms does this project target?)

| Platform | Status | Notes |
|----------|--------|-------|
| Web (Rails) | Active | Single platform — web only |

---

## Framework & Stack

(REQUIRED — language, framework, tools)

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

---

## Directory Structure

(REQUIRED — where things live in this repository)

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

---

## Implementation Order

(RECOMMENDED — natural build sequence when implementing a milestone)

1. Migration(s)
2. Model(s) — with validations, associations, scopes
3. Service(s) — business logic
4. Route(s)
5. Controller(s)
6. Views (ERB)
7. Stimulus controller(s)

---

## Post-Flight Checks

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

---

## Guardrails

(REQUIRED — safety rules for agents)

| Guardrail | Rule |
|-----------|------|
| **Production access** | Agents NEVER have production access. No deploy credentials, no production database access. |
| **Default branch** | Never commit or merge directly to the default branch. |
| **Push** | Never push without explicit user request. |
| **Destructive operations** | No `drop_table`, `reset`, or data deletion without human approval. |
