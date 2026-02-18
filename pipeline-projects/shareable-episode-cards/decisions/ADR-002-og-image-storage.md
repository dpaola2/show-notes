# ADR-002: OG Image Storage

**Date:** 2026-02-18
**Status:** Accepted
**Project:** shareable-episode-cards
**Stage:** 2

## Context

Generated OG images need to be stored persistently and served via the `og:image` meta tag. Two approaches: Active Storage (Rails' built-in file attachment system) or a simple `og_image_path` column with manual file management.

## Decision

Use Active Storage with a `has_one_attached :og_image` on the `Episode` model. This requires running `rails active_storage:install` to create the three Active Storage tables (`active_storage_blobs`, `active_storage_attachments`, `active_storage_variant_records`).

## Alternatives Considered

| Approach | Pros | Cons |
|----------|------|------|
| **Active Storage (chosen)** | Built-in Rails framework. Blob metadata tracking. Easy to swap storage backends (disk → S3). Variant support. Clean API (`episode.og_image.attached?`). | Requires running migration to create 3 tables. Adds some query overhead (joins through polymorphic attachment). |
| Simple path column + manual file management | No migration needed. Direct file path, no abstraction overhead. | Manual cleanup on delete. Manual storage backend switching. No metadata tracking. Reinvents what Active Storage already provides. |

## Consequences

- Three new Active Storage tables are created (one-time framework setup, not feature-specific).
- Active Storage service is already configured in `config/storage.yml` (disk-based for local/test, ready for S3 in production).
- `config/environments/production.rb` and `development.rb` already set `config.active_storage.service = :local`.
- OG image URLs are served through Rails' Active Storage proxy/redirect, which means they include a token. For OG images, we'll use `rails_blob_url` to generate a permanent URL.
- Future features that need file attachments (e.g., user avatars, audio caching) benefit from this one-time setup.
