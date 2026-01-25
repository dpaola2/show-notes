# ADR 002: Use AssemblyAI Instead of OpenAI Whisper for Transcription

## Status

Accepted

## Date

2026-01-25

## Context

We need to transcribe podcast audio files to generate summaries. Initially, we chose OpenAI's Whisper API, but encountered a significant limitation:

**Problem**: Whisper API has a 25MB file upload limit. Podcast episodes are typically 50-150MB, requiring us to:
1. Download the entire file locally
2. Compress it with ffmpeg (mono, 16kHz, 64kbps)
3. Upload the compressed file

This adds complexity, processing time, and a dependency on ffmpeg being installed.

## Decision

Switch from OpenAI Whisper API to **AssemblyAI** for transcription.

## Rationale

| Factor | Whisper API | AssemblyAI |
|--------|-------------|------------|
| Input method | File upload | URL (they fetch it) |
| File size limit | 25MB | None |
| Pricing | $0.006/min | $0.0065/min |
| Download required | Yes | No |
| Compression required | Yes (for large files) | No |
| Timestamp support | Yes (segments) | Yes (words + sentences) |

**Key advantages of AssemblyAI:**

1. **URL-based**: We pass the podcast's audio URL directly. AssemblyAI fetches it. No download, no upload, no file size issues.

2. **Simpler pipeline**:
   - Before: Download → Compress → Upload → Transcribe
   - After: Submit URL → Poll → Done

3. **No ffmpeg dependency**: Removes system dependency, simpler deployment.

4. **Better for podcasts**: Designed for long-form audio, handles hours-long files.

5. **Similar accuracy**: Both use similar underlying models.

**Tradeoffs:**

- Slightly higher cost ($0.0065 vs $0.006/min) — negligible
- Async API requires polling (not a real downside for background jobs)
- New API key needed

## Consequences

1. Replace `WhisperClient` with `AssemblyAIClient`
2. Update `ProcessEpisodeJob` to use URL-based transcription
3. Remove audio download/compression logic
4. Add `ASSEMBLYAI_API_KEY` environment variable
5. Update cost estimates (minimal change)

## Alternatives Considered

- **Deepgram**: Also URL-based, slightly cheaper ($0.005/min), but less familiar
- **Local Whisper**: No API costs, but requires GPU for reasonable speed
- **Keep Whisper + compression**: Works, but adds unnecessary complexity
