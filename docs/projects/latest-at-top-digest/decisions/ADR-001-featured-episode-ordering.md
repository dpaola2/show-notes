# ADR-001: Featured Episode Ordering

**Date:** 2026-02-19
**Status:** Accepted
**Project:** latest-at-top-digest
**Stage:** 2

## Context

The new digest design features a single "most recent" episode at the top. We need to decide how "most recent" is defined when selecting the featured episode from the batch of qualifying episodes.

Two timestamp columns are available: `episodes.published_at` (when the podcast published the episode) and `user_episodes.updated_at` (when the episode became library-ready for the user).

## Decision

Use `user_episodes.updated_at DESC` to determine the featured episode.

## Alternatives Considered

| Approach | Pros | Cons |
|----------|------|------|
| **`user_episodes.updated_at DESC` (chosen)** | Aligns with the digest's "since last sent" filter (also `updated_at`-based); reflects "newest in your library"; handles backfilled old episodes correctly | Less intuitive — users might expect "most recent" to mean publication date |
| `episodes.published_at DESC` | Matches user's mental model of "newest episode"; consistent with podcast app conventions | A newly-subscribed podcast could backfill old episodes, surfacing a weeks-old episode as "featured" over yesterday's episode from another show; `published_at` can be null or unreliable in some feeds |

## Consequences

- The featured episode is the one whose `user_episode` was most recently updated to `:ready` status — typically the last episode to finish processing
- If a user subscribes to a new podcast and old episodes are backfilled, they won't dominate the featured slot over genuinely new content from other subscriptions
- The sort order in the `library_ready_since` scope changes from `podcasts.title ASC, episodes.published_at DESC` to `user_episodes.updated_at DESC`
