# Show Notes

A "read-first" podcast player that uses AI to transcribe and summarize episodes, letting you triage your podcast backlog by reading instead of listening.

## The Problem

You subscribe to more podcasts than you can listen to. Traditional apps present an overwhelming feed of audio with no way to quickly assess what's worth your time.

## The Solution

1. **Triage** — New episodes land in an Inbox. You decide: add to Library or skip.
2. **Transcribe & Summarize** — Episodes in Library are processed by Whisper (transcription) and Claude (summarization).
3. **Read First** — Open an episode to see the AI summary with notable quotes. Audio is secondary.
4. **Tap to Listen** — Tap any quote to jump to that moment in the audio.

## Documentation

- **[PRD.md](./PRD.md)** — Product requirements, user flows, feature priorities
- **[TECHNICAL_GAMEPLAN.md](./TECHNICAL_GAMEPLAN.md)** — Architecture, data model, implementation phases

## Tech Stack

| Layer | Choice |
|-------|--------|
| Backend | Ruby 3.3.10, Rails 8, Solid Queue |
| Frontend | Hotwire (Turbo + Stimulus), Tailwind |
| Database | PostgreSQL |
| Hosting | Heroku |
| Transcription | OpenAI Whisper API |
| Summarization | Claude API |
| Podcast Data | Podcast Index API |

## Status

**Pre-development** — PRD and technical gameplan complete. Ready to build.

## Getting Started

(Setup instructions will be added once the app is scaffolded)

### Required API Keys

You'll need accounts and API keys from:
- [Podcast Index](https://podcastindex.org/) — Free, for podcast search and feeds
- [OpenAI](https://platform.openai.com/) — For Whisper transcription (~$0.006/min)
- [Anthropic](https://console.anthropic.com/) — For Claude summarization

### Environment Variables

```bash
# .env (local development)
DATABASE_URL=postgres://localhost/show_notes_development
PODCAST_INDEX_API_KEY=your_key
PODCAST_INDEX_API_SECRET=your_secret
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
SECRET_KEY_BASE=generate_with_rails_secret
```

## Cost Estimates

- **Per episode**: ~$0.45-0.55 (mostly Whisper transcription)
- **Heroku hosting**: ~$19/month (web dyno + worker dyno + Postgres)
- **10 episodes/week**: ~$39/month total

## License

Private project (for now).
