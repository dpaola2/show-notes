# OPML Import — PRD

|  |  |
| -- | -- |
| **Product** | Show Notes |
| **Version** | 1 |
| **Author** | Stage 0 (Pipeline) |
| **Date** | 2026-02-07 |
| **Status** | Draft — Review Required |
| **Platforms** | Web only |
| **Level** | 2 |

---

## 1. Executive Summary

**What:** A one-time onboarding flow that lets new users import their podcast subscriptions from apps like Overcast, Apple Podcasts, and Pocket Casts via OPML file upload. After import, users select their favorite podcasts, and the system processes the latest episode from each — so their first digest email arrives the next morning with real content.

**Why:** OPML import is the critical bridge between "signed up" and "getting value." Without it, new users face a cold start — empty inbox, no digest, no reason to return. Every competitor treats podcast import as table stakes. Phase 2 user onboarding (Mom Test participants) is blocked until this exists.

**Key Design Principles:**
- **Hide the format, lead with the app.** Users see "Import from Overcast" — never "Upload OPML file."
- **Cold start must be solved on day one.** Import without processing = no digest tomorrow = churned user.
- **Cost-controlled generosity.** Process 5-10 user-selected favorites (~$2-5), not the full library (~$11+).
- **One-time flow, razor-thin scope.** No sync, no merge. Re-import allowed (skips duplicates) but not a core workflow.

---

## 2. Goals & Success Metrics

### Goals
- Enable new users to bring their existing podcast subscriptions into Show Notes in under 5 minutes
- Ensure every user who completes the import flow receives a digest email the next morning with real content
- Keep per-user import cost within the $2-5 sweet spot

### Success Metrics

| Metric | Target | Timeframe |
|--------|--------|-----------|
| Import completion rate (started → confirmed) | > 70% | 30 days |
| Next-day digest delivery rate (for users who imported) | 100% | 30 days |
| Average AI cost per import | < $5.00 | 30 days |
| User retention at 7 days (imported vs. non-imported) | [NEEDS REVIEW — set baseline after first cohort] | 60 days |

---

## 3. Feature Requirements

### Import Flow

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| IMP-001 | User can initiate import from a prominent entry point in the UI | Web | Must |
| IMP-002 | Import flow shows generic instructions ("Export your OPML file from your podcast app and upload it here"). App-specific instructions deferred to later if users get confused. | Web | Must |
| IMP-003 | User can upload an OPML file (`.opml` or `.xml` extension) | Web | Must |
| IMP-004 | System parses the OPML file and extracts podcast feed URLs and titles | Web | Must |
| IMP-005 | System displays the list of discovered podcasts with names and artwork (if artwork URL is available in feed data — no extra API calls) after parsing | Web | Must |
| IMP-006 | System reports a count: "We found N podcasts!" | Web | Must |
| IMP-007 | System handles malformed or empty OPML files with a clear error message | Web | Must |

### Favorites Selection

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| FAV-001 | User can select 5-10 podcasts as favorites from the imported list | Web | Must |
| FAV-002 | System enforces a minimum selection (at least 1) before proceeding | Web | Must |
| FAV-003 | System shows a recommended range ("Pick 5-10 of your favorites") but does not hard-cap the maximum | Web | Should |
| FAV-004 | Selection UI allows select-all / deselect-all for convenience | Web | Nice |

### Processing & Cost

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| PRC-001 | System processes the latest episode from each selected favorite podcast | Web | Must |
| PRC-002 | System displays a cost estimate before the user confirms processing: "We'll process N episodes from your favorite shows (~$X.XX)" | Web | Must |
| PRC-003 | Processing happens in the background after user confirms | Web | Must |
| PRC-004 | System shows a confirmation message after user confirms: "Your first digest arrives tomorrow morning" | Web | Must |
| PRC-005 | Non-selected podcasts are subscribed (feed polling starts) but no episodes are processed | Web | Must |

### Feed Subscription

| ID | Requirement | Platform | Priority |
|----|------------|----------|----------|
| SUB-001 | All imported podcasts (selected and non-selected) are added as subscriptions | Web | Must |
| SUB-002 | Subscriptions start polling for new episodes going forward — no backlog import | Web | Must |
| SUB-003 | Duplicate feeds (already subscribed) are skipped without error | Web | Must |
| SUB-004 | Feeds that cannot be found or resolved show a warning but don't block the import | Web | Should |

---

## 4. Platform-Specific Requirements

### Web (Rails)
- **Primary entry point:** Dashboard empty state CTA — when a user has zero subscriptions, the dashboard shows a prominent "Import your podcasts" CTA
- **Secondary entry point:** Settings page — for users who come back later or want to import from a second app
- No onboarding wizard — users are personally onboarded by Dave at this stage
- Upload uses standard browser file picker (no drag-and-drop required, but nice to have)
- Favorites selection uses a responsive grid/list with checkboxes
- Cost estimate uses the existing cost estimation logic already in the product
- Background processing uses Solid Queue jobs

### iOS
- No changes required — Level 2 project (web only)

### Android
- No changes required — Level 2 project (web only)

### API
- No changes required — Level 2 project (web only, no mobile clients)

---

## 5. User Flows

### Flow 1: Happy Path — Import and Process Favorites

**Persona:** New user who just signed up, has 15-30 podcast subscriptions in another app
**Entry Point:** Dashboard empty state CTA ("Import your podcasts")

1. User clicks "Import your podcasts"
2. User sees generic export instructions: "Export your OPML file from your podcast app and upload it here"
3. User uploads their OPML file via file picker
4. System parses the file and shows: "We found 27 podcasts!"
5. System displays the podcast list with names and artwork
6. User selects 7 favorites from the list
7. System shows cost estimate: "We'll process 7 episodes from your favorite shows (~$3.22). Your first digest arrives tomorrow morning."
8. User confirms
9. System subscribes to all 27 feeds, queues processing for the 7 selected episodes
10. User sees confirmation: "You're all set! Your first digest arrives tomorrow morning."
11. **Success:** Next morning, user receives a digest email with summaries from their 7 selected shows

### Flow 2: File Error

**Persona:** User who uploads a non-OPML file or corrupted file
**Entry Point:** Step 3 of Flow 1

1. User uploads a file that isn't valid OPML
2. System shows error: "We couldn't read that file. Make sure you're uploading the OPML export from your podcast app."
3. User can re-upload a different file
4. **Error recovery:** User tries again with the correct file → continues from Step 4 of Flow 1

### Flow 3: No Podcasts Found

**Persona:** User who uploads an OPML file with no podcast feeds
**Entry Point:** Step 3 of Flow 1

1. User uploads a valid OPML file that contains no podcast feeds (e.g., an RSS reader OPML)
2. System shows: "We didn't find any podcast feeds in that file. Make sure you're exporting from your podcast app, not your RSS reader."
3. User can re-upload
4. **Error recovery:** Same as Flow 2

---

## 6. UI Mockups / Wireframes

### Step 1: Upload
```
┌─────────────────────────────────────┐
│  Import your podcasts               │
│                                     │
│  Export your OPML file from your    │
│  podcast app and upload it here.    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │   Choose file...            │    │
│  └─────────────────────────────┘    │
│                                     │
│  [Upload & Continue]                │
└─────────────────────────────────────┘
```

### Step 2: Favorites Selection
```
┌─────────────────────────────────────┐
│  We found 27 podcasts!              │
│  Pick your favorites (5-10)         │
│                                     │
│  ☑ The Daily          ☑ Huberman    │
│  ☐ Planet Money       ☑ Lex Fridman │
│  ☑ Acquired           ☐ 99% Invis. │
│  ☑ Hardcore History   ☐ Reply All   │
│  ☐ This Am. Life      ☑ All-In     │
│  ...                                │
│                                     │
│  7 selected · ~$3.22               │
│  [Process my favorites]             │
└─────────────────────────────────────┘
```

### Step 3: Confirmation
```
┌─────────────────────────────────────┐
│  ✓ You're all set!                  │
│                                     │
│  We're processing 7 episodes from   │
│  your favorite shows now.           │
│                                     │
│  Your first digest arrives          │
│  tomorrow morning.                  │
│                                     │
│  [Go to dashboard]                  │
└─────────────────────────────────────┘
```

---

## 7. Backwards Compatibility

N/A — no API or client-facing changes. Web-only feature, no mobile clients affected.

---

## 8. Edge Cases & Business Rules

| Scenario | Expected Behavior | Platform |
|----------|-------------------|----------|
| User uploads a non-OPML file (e.g., .pdf, .jpg) | Show error: "We couldn't read that file." Allow re-upload. | Web |
| OPML file contains 0 podcast feeds | Show message: "We didn't find any podcast feeds." Allow re-upload. | Web |
| OPML file contains feeds user is already subscribed to | Skip duplicates silently. Show count of *new* podcasts found. | Web |
| OPML file contains feeds that can't be resolved (dead URLs) | Show summary at the end: "We couldn't find 3 feeds" with expandable details. Don't clutter the favorites selection. | Web |
| User selects 0 favorites and tries to proceed | Require at least 1 selection. Show inline validation. | Web |
| User selects all 27 podcasts as favorites | Allow it. The cost estimate IS the warning — informed consent. No separate "are you sure?" prompt. | Web |
| User closes browser mid-flow after upload but before confirming | Require re-upload. No persisted mid-flow state — re-upload takes 10 seconds. | Web |
| User imports twice (comes back and re-uploads) | Allow re-import. Skip already-subscribed feeds, import what's new. Supports users who switch between multiple podcast apps. | Web |
| OPML file is very large (100+ feeds) | Parse and display all. Performance should be acceptable for up to 500 feeds. | Web |
| Processing job fails for one episode | Process remaining episodes. Failed episode logged. Digest still sends with available content. [INFERRED] | Web |
| User imports at 11:59 PM — next digest is in 1 minute | Processing may not complete in time. Digest includes whatever is ready. Next digest will have the rest. [INFERRED] | Web |
| OPML file uses nested folder structure (categories) | Flatten to a single list of feeds. Ignore folder hierarchy. [INFERRED] | Web |

---

## 9. Export Requirements

N/A — this feature is an import flow, not a data export.

---

## 10. Out of Scope

- **Ongoing sync** — import is a one-time action per app, not a persistent sync connection
- **Merge UI / duplicate resolution** — re-import silently skips already-subscribed feeds; no user-facing merge
- **Backlog processing** — only the latest episode from selected favorites is processed; no historical episode import
- **Drag-and-drop upload** — standard file picker only (drag-and-drop is a nice-to-have, not required)
- **Podcast search / manual add from import flow** — import is file-based only; manual subscription is a separate feature
- **Real-time progress indicator** — no progress UI during background processing. "Your first digest arrives tomorrow morning" is the promise. User closes the tab.
- **App-specific export instructions** — ship with generic "export your OPML" text. Add per-app instructions later if users get confused.
- **Mobile app import** — web only; no iOS/Android import UI

---

## 11. Open Questions

| #   | Question                                                                                                                                                      | Status   | Decision                                                                                                                          | Blocking? |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------- | --------- |
| 1   | Where does the import entry point live? Onboarding flow, dashboard CTA, settings page, or all of the above?                                                   | Resolved | Dashboard empty state CTA (primary) + settings page (secondary). No onboarding wizard.                                            | Yes       |
| 2   | Should we persist parsed OPML state if the user abandons mid-flow, or require re-upload?                                                                      | Resolved | No persistence. Re-upload takes 10 seconds. Not worth the engineering.                                                            | No        |
| 3   | Should re-import be blocked entirely, or allowed with duplicate-skip behavior?                                                                                | Resolved | Allow re-import, skip duplicates. Users may import from multiple apps.                                                            | No        |
| 4   | Should we warn or soft-cap when a user selects many favorites (e.g., 15+)?                                                                                    | Resolved | No warning. The cost estimate IS the warning — informed consent.                                                                  | No        |
| 5   | Should there be a real-time progress indicator during background processing, or just the "digest tomorrow" confirmation?                                      | Resolved | No progress indicator. "Digest tomorrow" is the promise. Over-engineering for zero user value at this stage.                      | No        |
| 6   | How should unresolvable feed URLs be surfaced? Inline warning per feed, or a summary at the end?                                                              | Resolved | Summary at the end: "We couldn't find 3 feeds" with expandable list. Don't clutter favorites selection.                          | No        |
| 7   | Should podcast artwork be fetched and displayed during the selection step, or just show text names? Artwork is more engaging but adds complexity and latency. | Resolved | Show artwork if URL is available in feed data (it usually is). No extra API calls to fetch it — use what's already in the data.   | No        |
| 8   | What are the app-specific OPML export instructions for each supported app? Need to verify current UIs for Overcast, Apple Podcasts, Pocket Casts.             | Resolved | Ship with generic instructions. Add app-specific instructions later if users get confused. Don't let this block shipping.         | No        |

**Assessment:** All questions resolved. No blocking questions remain — this PRD is ready for pipeline intake (after final human review).

---

## 12. Release Plan

### Phases

| Phase | What Ships | Flag | Audience |
|-------|-----------|------|----------|
| Phase 1 | Full import flow (upload → select favorites → process → digest) | None | All users |

### Feature Flag Strategy
- No feature flag. Single-user app with 5 beta testers — ship directly. Feature flags are for protecting thousands of users from bad rollouts.

---

## 13. Assumptions

- The existing cost estimation logic in Show Notes can be reused for the pre-processing cost estimate (PRC-002)
- Solid Queue can handle the processing load from a single user's import (5-10 concurrent jobs)
- Podcast feed URLs in OPML files are standard RSS/Atom URLs that the existing feed subscription system can handle
- Show Notes already has a concept of "subscriptions" and "feed polling" that imported feeds can plug into
- The daily digest email system is already functional and will automatically include newly processed episodes
- OPML files from major podcast apps (Overcast, Apple Podcasts, Pocket Casts) follow the standard OPML 2.0 format with `<outline>` elements containing `xmlUrl` attributes
- AI processing cost per episode is approximately $0.46 (as stated in the framing doc)

---

## Appendix: Linked Documents

| Document | Link |
|----------|------|
| Framing Doc | `inbox/opml-import-framing.md` |
| Linear Project | [Not yet created] |
| Snipd Onboarding Insight | Referenced in framing doc — "Snipd's Onboarding Validates Our OPML Priority" |
| Digest-as-Product Insight | Referenced in framing doc — "The Daily Digest Is the Product" |
