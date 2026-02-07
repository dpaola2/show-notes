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
| Web (Rails) | Active | Only platform |

---

## Framework & Stack

(REQUIRED — language, framework, tools)

| Setting | Value |
|---------|-------|
| **Language** | Ruby 3.3 |
| **Framework** | Rails 8.1 |
| **Test framework** | RSpec |
| **ORM** | ActiveRecord |
| **Serialization** | Jbuilder |
| **Frontend JS** | Stimulus (Hotwire) + Importmap |
| **CSS** | Tailwind CSS |
| **Database** | SQLite (dev/test), PostgreSQL (CI) |
| **Asset pipeline** | Propshaft |
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
| JavaScript controllers | `app/javascript/controllers/` |
| Background jobs | `app/jobs/` |
| Mailers | `app/mailers/` |
| Routes | `config/routes.rb` |
| Migrations | `db/migrate/` |
| Schema | `db/schema.rb` |
| Model specs | `spec/models/` |
| Request specs | `spec/requests/` |
| Service specs | `spec/services/` |
| Job specs | `spec/jobs/` |
| Mailer specs | `spec/mailers/` |
| Factories | `spec/factories/` |

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
| **Ruby style** | `bundle exec rubocop -A` | Yes | Yes — commit fixes, re-run to confirm clean |
| **Security scan** | `bundle exec brakeman -q --no-pager` | No | Yes — high/critical findings block the PR |
| **Gem audit** | `bundle exec bundler-audit` | No | Yes — any findings block the PR |

> The `/create-pr` skill reads this table and runs each check on the project branch before pushing.
> Auto-fixable checks are run first; their fixes are committed. Then report-only checks run.
> If any blocking check fails after auto-fix, the skill stops and reports the findings.

---

## Guardrails

(REQUIRED — safety rules for agents)

| Guardrail | Rule |
|-----------|------|
| **Default branch** | Never commit or merge directly to `main`. |
| **Push** | Never push without explicit user request. |
| **Destructive operations** | No `drop_table`, `reset`, or data deletion without human approval. |
