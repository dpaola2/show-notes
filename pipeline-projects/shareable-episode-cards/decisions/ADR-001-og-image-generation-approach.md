# ADR-001: OG Image Generation Approach

**Date:** 2026-02-18
**Status:** Accepted
**Project:** shareable-episode-cards
**Stage:** 2

## Context

The feature requires auto-generating 1200x630 Open Graph images for each summarized episode. The images include podcast artwork, episode title, a quote excerpt, and Show Notes branding. Several approaches exist for server-side image generation in a Rails environment.

## Decision

Use Ruby `image_processing` gem with libvips for server-side image compositing. Generate images as a background job (`GenerateOgImageJob`) triggered after summary creation.

## Alternatives Considered

| Approach | Pros | Cons |
|----------|------|------|
| **image_processing + vips (chosen)** | Already in Gemfile and Dockerfile (`libvips` installed). No new dependencies. Fast compositing. Works with Active Storage. | Text rendering is basic (no rich typography). Layout must be computed manually. |
| HTML/CSS → screenshot (Puppeteer/Grover) | Flexible layout with full CSS support. Easy to design in browser. | Adds headless Chrome to Docker image (~400MB+). Significant new dependency. Slow rendering. Memory-intensive. |
| Third-party OG service (Vercel OG, Cloudinary) | No server-side image processing. Rich templates. | External dependency. Cost at scale. Latency for first render. Vendor lock-in. |
| SVG → PNG conversion | Good text layout control. Declarative. | Requires librsvg or similar. Font handling is tricky. Less battle-tested in Rails ecosystem. |

## Consequences

- Image layout is limited to what vips can compose (rectangles, text overlays, image placement). No CSS-like flexbox or complex typography.
- The OG image will have a simple, clean design rather than a pixel-perfect marketing asset. This is appropriate for v1.
- If richer layouts are needed later, we can swap the generation backend without changing the storage or triggering architecture.
- Text truncation for long titles/quotes must be handled in Ruby before rendering.
