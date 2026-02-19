# Library-Scoped Processing

## Context

Show Notes was originally designed for a single user (me) but recent features were built assuming multi-user/newsletter use cases. Two areas drifted from what I actually need:

1. **Email digests** now include every new episode from subscribed podcasts (the Feb 7 newsletter redesign). I only care about episodes I've explicitly put into my library.

2. **Transcription** now runs automatically on every new episode discovered by feed fetch (`AutoProcessEpisodeJob`). This burns API credits (AssemblyAI, Claude) on episodes I may never read. I only want to transcribe episodes I've moved to my library.

## What Should Change

### Digest emails: library episodes only

Revert the digest from "all new episodes from subscriptions" back to showing library episodes. The current subscription-based query (`Episode.joins(podcast: :subscriptions)`) should be replaced with a query against `user_episodes` in library location.

The digest should answer: "here are your library episodes that are ready or recently became ready" — not "here's everything your podcasts published today."

### Transcription: library only, not on feed fetch

Remove or disable `AutoProcessEpisodeJob` from the feed fetch flow. When `FetchPodcastFeedJob` discovers new episodes, it should still create inbox `UserEpisode` records, but should NOT enqueue transcription.

Transcription should only happen when a user moves an episode to the library (the existing `ProcessEpisodeJob` pathway via `move_to_library!`).

## What Should NOT Change

- Feed fetching still discovers and creates episodes + inbox entries automatically
- The inbox still shows new episodes from subscribed podcasts
- `ProcessEpisodeJob` (user-triggered, library pathway) stays as-is
- `DetectStuckProcessingJob` stays — it's still useful for library processing
- Episode-level processing state columns stay — useful for shared transcript caching
- Inbox processing status display (from tweak-transcribe-ux M3) can stay, but inbox episodes will mostly show as "pending" since auto-processing is removed

## Motivation

This is a personal tool. I don't need a newsletter covering every episode — I want a digest of things I've curated. And I don't want to pay for transcription of episodes I'll never read.
