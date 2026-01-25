# Show Notes — Product Requirements Document

## Overview

**Show Notes** is a podcast player designed for the time-constrained listener. Rather than treating podcasts as audio-first content, it treats them as *readable* content that happens to have audio attached.

### Problem Statement

Podcast listeners often subscribe to more shows than they can realistically listen to. Traditional podcast apps present an overwhelming feed of audio content with no good way to quickly assess which episodes are worth the time investment. Show notes, when they exist, are often sparse or promotional rather than informative.

### Solution

A "read-first" podcast player that:
1. Forces intentional curation through a triage flow
2. Automatically transcribes and summarizes episodes using AI
3. Presents summaries as the primary interface, with audio playback as secondary
4. Lets users tap notable quotes to jump directly to those moments in the audio

---

## Goals & Non-Goals

### Goals
- Reduce podcast overwhelm through forced triage
- Let users extract value from episodes without listening
- Make listening *optional* but seamless when desired
- Keep the interface minimal and fast

### Non-Goals
- Social features (sharing, comments, recommendations)
- Podcast creation/publishing tools
- Offline-first architecture (nice to have, not required for v1)
- Discovery algorithms or personalized recommendations

---

## Target Users

**Primary**: The user is a podcast enthusiast with 15+ subscriptions who has accumulated a backlog of hundreds of unplayed episodes. They want to stay informed on topics they care about but have limited listening time (commute, exercise, chores).

**Usage context**: Personal use with potential expansion to a small group of friends/family.

---

## User Flows

### Flow 1: Subscribe to a Podcast
1. User searches for a podcast by name or browses categories
2. User taps "Subscribe"
3. Podcast appears in subscriptions list
4. Last 10 episodes appear in the Inbox (older episodes accessible via Show Archive)

**Alternative**: User imports subscriptions via OPML file.

### Flow 2: Triage Inbox
1. User opens Inbox and sees episodes awaiting triage (newest first)
2. For each episode, user can:
   - **Add to Library** → Episode is downloaded and queued for transcription
   - **Skip** → Episode moves to Trash
   - *(No action)* → Episode remains in Inbox indefinitely
3. Inbox badge shows count of untriaged episodes
4. Goal: Inbox Zero — all episodes either added to Library or skipped to Trash

### Flow 2a: Browse Show Archive
1. User searches for any podcast (subscribed or not)
2. User opens the show's episode archive
3. User can:
   - **Add to Inbox** → Queue for later triage
   - **Add to Library** → Skip triage, immediately download and process
4. This allows cherry-picking old episodes or sampling shows before subscribing
5. If episode already exists elsewhere (Inbox, Library, Archive, Trash), it silently moves to the target location

### Flow 2b: Trash Management
1. Skipped episodes live in Trash
2. User can restore episodes from Trash back to Inbox
3. Trash auto-empties episodes older than 90 days

### Flow 2c: Archive (Done Episodes)
1. When finished with a Library episode, user marks it as "Done" → moves to Archive
2. Archive holds completed episodes indefinitely (no auto-delete)
3. User can browse Archive to revisit old summaries
4. User can restore episodes from Archive back to Library if needed

### Flow 3: Read an Episode
1. User opens Library
2. User taps an episode
3. **Primary view**: AI-generated summary with:
   - Multi-section breakdown of the episode
   - Notable quotes (tappable)
   - Original show notes (if available) in a collapsible section
4. **Secondary view/tab**: Audio player with basic controls

### Flow 4: Listen to an Episode
1. From the episode view, user switches to audio tab/section
2. Basic playback: play/pause, seek bar, current position
3. Alternatively: user taps a notable quote → audio jumps to that timestamp and begins playing

### Flow 5: Search
1. User opens search
2. User types a query
3. Results show matching episodes based on AI summary content
4. User taps a result to open that episode

---

## Features & Requirements

### Inbox (Triage)

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Chronological list of new episodes from subscriptions | P0 | Newest first |
| "Add to Library" action | P0 | Triggers download + transcription |
| "Skip" action | P0 | Moves episode to Trash |
| Episodes persist in Inbox until acted upon | P0 | No auto-expiration; Inbox Zero is the goal |
| Badge count showing Inbox size | P1 | |

### Trash

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Holds skipped episodes | P0 | |
| Restore to Inbox action | P1 | Undo a skip |
| Auto-delete episodes older than 90 days | P1 | Configurable retention period |
| Manual empty trash | P2 | |

### Show Archive (Podcast Browser)

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Browse full episode history for any podcast | P0 | Works for subscribed and non-subscribed shows |
| "Add to Inbox" action | P0 | Queue episode for later triage |
| "Add to Library" action | P0 | Skip triage, immediately process |
| Silent duplicate handling | P0 | If episode exists elsewhere, move it to target location |

### Library

| Requirement | Priority | Notes |
|-------------|----------|-------|
| List of all active episodes | P0 | Sorted by date added |
| Status indicators | P0 | Downloading, Transcribing, Ready |
| Detailed error states | P0 | If processing fails, show what went wrong (not just "Error") |
| Episode detail view | P0 | Summary first, audio second |
| "Done" action (move to Archive) | P0 | Marks episode as finished |
| Filter by podcast | P2 | |

### Archive

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Holds completed/done episodes | P0 | No auto-delete, persists indefinitely |
| Browse archived episodes | P0 | View old summaries anytime |
| Restore to Library | P1 | Move episode back to active Library |

### AI Summarization

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Cost estimate before processing | P0 | Show "~$0.45" before adding to Library |
| Automatic transcription on add-to-library | P0 | Via OpenAI Whisper API |
| AI-generated summary (multi-section) | P0 | Via Claude API |
| Notable quotes extraction with timestamps | P0 | Tappable to jump to audio position |
| Background processing with status updates | P1 | User shouldn't have to wait |
| Retry failed transcriptions | P1 | |
| Regenerate summary | P1 | Re-run summarization if user isn't satisfied |

### Audio Playback

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Play/pause | P0 | |
| Seek bar with current position | P0 | |
| Jump to timestamp (from quote tap) | P0 | |
| Background audio | P1 | Continue playing when app backgrounded |
| Playback speed control | P2 | Not in initial scope, but low effort |
| Skip forward/back buttons | P2 | 15s or 30s increments |

### Podcast Management

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Search for podcasts | P0 | Via podcast index/directory API |
| Subscribe/unsubscribe | P0 | |
| View subscriptions list | P0 | |
| OPML import | P1 | For migrating from other apps |
| OPML export | P2 | |

### Search

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Search across AI summaries | P1 | Full-text search of summary content |
| Results link to episode detail | P1 | |

---

## Information Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│  App                                                                  │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   Inbox     │  │   Library   │  │   Archive   │  │   Search    │  │
│  │  (Triage)   │  │  (Active)   │  │   (Done)    │  │             │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │
│         │                │                │                │         │
│    Add to Library        │      Done      │                │         │
│    ─────────────────────►│───────────────►│                │         │
│         │                │                │                │         │
│         │                │◄───────────────┘                │         │
│         │                │    Restore                      │         │
│    Skip │                │                                 │         │
│         │                ▼                                 │         │
│         │         ┌─────────────┐                          │         │
│         │         │  Episode    │◄─────────────────────────┘         │
│         │         │  Detail     │                                    │
│         ▼         ├─────────────┤                                    │
│  ┌─────────────┐  │ [Summary]   │ ← Primary view                     │
│  │   Trash     │  │ [Audio]     │ ← Secondary view                   │
│  │ (90d auto-  │  └─────────────┘                                    │
│  │  delete)    │                                                     │
│  └──────┬──────┘                                                     │
│         │ Restore                                                    │
│         └────────► Inbox                                             │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐                                    │
│  │  Podcasts   │  │   Settings  │                                    │
│  │  (Browse)   │  │             │                                    │
│  └──────┬──────┘  └─────────────┘                                    │
│         │                                                            │
│         ▼                                                            │
│  ┌─────────────┐                                                     │
│  │ Show Archive│──► Add to Inbox OR Add to Library                   │
│  │ (any show)  │                                                     │
│  └─────────────┘                                                     │
│                                                                      │
└───────────────────────────────────────────────────────────────────────┘
```

**Episode Lifecycle:**
```
                    ┌─────────┐
                    │  Inbox  │◄──────────────────────┐
                    └────┬────┘                       │
                         │                            │
          ┌──────────────┼──────────────┐             │
          │ Add to       │              │ Skip        │ Restore
          │ Library      │              ▼             │
          ▼              │         ┌─────────┐        │
     ┌─────────┐         │         │  Trash  │────────┘
     │ Library │         │         └────┬────┘
     │ (Active)│         │              │
     └────┬────┘         │              ▼
          │              │         Auto-delete
          │ Done         │         (90 days)
          ▼              │
     ┌─────────┐         │
     │ Archive │◄────────┘ (from Show Archive: Add to Library)
     │ (Done)  │
     └─────────┘
```

---

## Technical Considerations

### Platform Strategy

Given past challenges with iOS scope, a **web-first approach** is recommended:

1. **Phase 1**: Web application (responsive, works on mobile browsers)
   - Faster iteration, easier deployment
   - Validates core concept before native investment
   - PWA capabilities for app-like experience on mobile

2. **Phase 2** (optional): Native iOS app
   - Once web version is stable and concept is validated
   - Better background audio, notifications, offline support
   - Could share backend with web version

### AI Pipeline

```
Episode Audio
     │
     ▼
┌─────────────────┐
│ OpenAI Whisper  │  → Transcript (with timestamps)
│ API             │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Claude API      │  → Summary + Notable Quotes
│                 │     (with timestamp references)
└────────┬────────┘
         │
         ▼
    Stored in DB
```

### Cost Estimates (rough)

- **Whisper API**: ~$0.006/minute of audio
  - 1-hour episode ≈ $0.36
  - 10 episodes/week ≈ $15/month

- **Claude API**: Varies by model and tokens
  - Transcript input + summary output
  - Estimate ~$0.02–0.10 per episode depending on length

### Open Technical Questions

1. **Podcast directory API**: Apple Podcasts API, Podcast Index, or other?
2. **Audio hosting**: Stream from original source or cache locally?
3. **Database**: SQLite (simple), PostgreSQL (scalable), or other?
4. **Hosting**: Vercel, Railway, self-hosted VPS?

---

## Resolved Questions

| Question | Decision |
|----------|----------|
| Snooze action for Inbox items? | No — skip for v1, Inbox persists anyway |
| Regenerate summaries? | Yes — add regenerate button (P1) |
| Configurable Trash retention? | No — 90 days fixed |

---

## Success Metrics

For personal use, success is qualitative:
- Do you actually use it?
- Do you feel less overwhelmed by your podcast backlog?
- Are you discovering valuable content you would have missed?

---

## Future Considerations (Out of Scope for v1)

- Offline support with downloaded audio (important for mobile — Phase 2 priority)
- Episode notes/annotations
- Playback progress tracking (resume where you left off)
- Smart playlists (e.g., "all episodes under 30 min")
- Share summaries with others
- Push notifications when new episodes arrive
- Email digest of Inbox activity

---

*Document version: 1.3*
*Last updated: 2025-01-25*
