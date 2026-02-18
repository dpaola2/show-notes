---
type: product-framing
tags: [product, api, knowledge-graph, status/inbox]
created: 2026-02-18
---

# Entity Extraction — Product Framing

> Add structured entity extraction to the existing summarization pipeline. Same Claude API call, richer output. Every episode gets people, topics, claims, and recommendations extracted alongside the prose summary.

---

## Why

The summarization pipeline currently produces human-readable sections and quotes. That's good for reading. It's useless for querying across episodes.

Entity extraction turns isolated summaries into a **connected knowledge graph**. Once you know that "Jensen Huang" appears in 47 episodes and "AI regulation" is discussed in 200+, you can build cross-episode search, topic trends, person tracking, and eventually an API that agents will pay to query.

This is Layer 2 of the Podcast Intelligence Platform strategy (see `assistant/05-projects/show-notes/strategy/podcast-intelligence-platform.md`). Layer 1 (text) exists. Layer 2 (structured data) is what this builds. Layer 3 (API for agents) comes later and depends on this.

**The economics case:** Every transcription at $0.46 is currently a cost. With entity extraction, it's also an investment in a data asset. A cached entity query costs ~$0.001 to serve. At $0.01/query to agents, 46 queries pay for the original transcription — and then it's margin forever.

---

## How It Works Today

`ClaudeClient` has three prompts:

1. **`SUMMARIZE_PROMPT`** — single short episodes → 3-6 sections + 3-5 quotes
2. **`CHUNK_SUMMARIZE_PROMPT`** — per-chunk for long transcripts → 2-3 sections + 2-4 quotes per chunk
3. **`SYNTHESIS_PROMPT`** — merges chunk summaries → 3-6 final sections + 3-5 best quotes

All three return JSON with `sections` and `quotes` keys. The `Summary` model stores these as JSON columns.

**The seam:** The synthesis prompt (or the single-episode prompt for short episodes) is where entity extraction should happen. It already produces the final structured output — adding an `entities` key to that JSON is the minimal change.

---

## What to Build

### 1. Enrich the summarization prompts

Add entity extraction instructions to `SUMMARIZE_PROMPT` and `SYNTHESIS_PROMPT`. The output JSON gains an `entities` key:

```json
{
  "sections": [...],
  "quotes": [...],
  "entities": {
    "people": [
      {"name": "Jensen Huang", "role": "CEO of NVIDIA", "context": "discussed AI chip demand"}
    ],
    "topics": [
      {"name": "AI chip supply chain", "relevance": "primary"},
      {"name": "AGI timeline predictions", "relevance": "secondary"}
    ],
    "claims": [
      {"speaker": "Jensen Huang", "claim": "AI inference demand will 10x by 2027", "start_time": 872}
    ],
    "recommendations": [
      {"type": "book", "title": "The Chip War", "recommended_by": "host"}
    ]
  }
}
```

**Entity types to extract:**

| Entity | What It Is | Why It Matters |
|--------|-----------|----------------|
| **People** | Anyone mentioned by name (guests, referenced figures) with role/context | Cross-episode person tracking, "what has [person] said?" |
| **Topics** | Subject areas discussed, with primary/secondary relevance | Topic trending, discovery, cross-episode themes |
| **Claims** | Specific assertions by specific speakers with timestamps | Fact tracking, position evolution, contradiction detection |
| **Recommendations** | Books, tools, products, other podcasts mentioned | "Most recommended books across tech podcasts" |

Don't over-extract. Start with these four. Add more entity types later if these prove useful.

### 2. Store entities

Two options — builder decides:

**Option A: JSONB column on summaries**
- Add `entities` JSONB column to `summaries` table
- Simplest. Entities live alongside sections/quotes.
- Downside: cross-episode queries require scanning every summary's JSON. Fine for <10K episodes, gets slow after.

**Option B: Normalized entities table**
- New `entities` table: `id`, `episode_id`, `entity_type` (enum: person/topic/claim/recommendation), `name`, `metadata` (JSONB for role/context/speaker/etc.), `start_time`
- Cross-episode queries are fast SQL: `Entity.where(entity_type: :person, name: "Jensen Huang").includes(:episode)`
- More work upfront but pays off when querying at scale.

**Recommendation:** Start with Option A for the spike. Migrate to Option B when you want cross-episode queries. Don't over-engineer the storage before you know the extraction is accurate.

### 3. Backfill existing episodes

Rake task that re-runs entity extraction on episodes that already have summaries. Two approaches:

- **Re-summarize:** Run the full enriched prompt against existing transcripts. More expensive (~$0.10/episode) but gets both updated summaries and entities.
- **Extract-only:** Run a lighter, entity-extraction-only prompt against existing `searchable_text` or summary sections. Cheaper but lower quality since it's working from summaries, not transcripts.

Start with extract-only for backfill. New episodes get the full enriched prompt going forward.

### 4. Verify in console

No UI needed for the spike. Just query in `rails console`:

```ruby
# Most mentioned people across all episodes
Entity.where(entity_type: :person).group(:name).count.sort_by(&:last).reverse.first(20)

# All episodes discussing "AI regulation"
Entity.where(entity_type: :topic, name: "AI regulation").includes(:episode).map { |e| e.episode.title }

# Books recommended across the corpus
Entity.where(entity_type: :recommendation).where("metadata->>'type' = ?", "book").pluck("metadata->>'title'").tally.sort_by(&:last).reverse

# What has Jensen Huang been discussed saying?
Entity.where(entity_type: :claim).where("metadata->>'speaker' = ?", "Jensen Huang").pluck(:name, "metadata->>'claim'")
```

---

## What NOT to Build (Yet)

- **UI for entity browsing.** Console queries first. Surface in the product only after you've confirmed the data is interesting and accurate.
- **API endpoints.** Way too early. Build the data layer, verify quality, then expose.
- **Entity deduplication / normalization.** "Jensen Huang" and "Huang" and "NVIDIA CEO" might all refer to the same person. Don't solve this now. Just extract and see what the raw data looks like.
- **Topic taxonomy / controlled vocabulary.** Let Claude pick topics freely. See what clusters emerge before imposing structure.

---

## Open Questions for the Builder

1. **How much does entity extraction increase the output token count?** The current summary JSON is maybe 500-1000 tokens. Entities might add 200-500 tokens. At Claude's output pricing, this is pennies per episode — but worth measuring.

2. **Should `CHUNK_SUMMARIZE_PROMPT` also extract entities per-chunk, or only at synthesis time?** Per-chunk extraction might catch entities that get lost in synthesis (a person mentioned briefly in chunk 3 of 8). But it means the synthesis prompt also needs to merge/deduplicate entities across chunks.

3. **How accurate is speaker attribution in multi-guest episodes?** The transcript has diarization from AssemblyAI (`Speaker N: text`), but speakers aren't identified by name. Claude infers names from context. This will be imperfect for multi-guest shows. Is "imperfect but present" better than "absent"?

4. **What's the right granularity for topics?** "AI" is too broad. "The impact of NVIDIA H100 GPU supply constraints on inference pricing for small language model startups" is too narrow. The prompt needs guidance on topic granularity — probably 2-4 word noun phrases.

---

## Success Criteria

- Entity extraction runs on new episodes without slowing down the processing pipeline noticeably
- Cross-episode queries in console return interesting, non-obvious results (e.g., "I didn't realize these 5 episodes all discussed the same person")
- Entity accuracy is good enough that >80% of extracted entities are correct (spot-check a sample)
- The data makes you want to build a UI for it

---

## Links

- `assistant/05-projects/show-notes/strategy/podcast-intelligence-platform.md` — Full strategy doc
- `assistant/05-projects/show-notes/insights/agent-native-api-service.md` — Insight: agent API opportunity
- `app/services/claude_client.rb` — Current summarization prompts (the code to modify)
- `app/services/transcript_chunker.rb` — Chunking strategy
- `app/models/summary.rb` — Current Summary model (sections + quotes)
- `app/jobs/process_episode_job.rb` — Processing orchestration

---

*This is a framing doc, not a spec. The builder decides how.*
