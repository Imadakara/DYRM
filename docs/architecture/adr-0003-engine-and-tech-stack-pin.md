# ADR-0003: Engine, Language, and Tech Stack Pin (Godot 4.7 / GDScript / Jolt / D3D12)

## Status
Accepted

## Date
2026-07-25 (decided at project start, before ТЗ-000; retrofitted into ADR format
2026-07-28 during gamedev plugin adoption)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (Forward+ renderer) |
| **Domain** | Core |
| **Knowledge Risk** | MEDIUM (engine version) mitigated to LOW by policy — see Decision |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None (that is the entire point of this ADR) |
| **Verification Required** | Any API used from 4.3–4.7 specifically (not present since 4.2) should be flagged and verified against official docs before use |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Every other ADR and GDD in the project — this is the foundational technical pin |
| **Blocks** | Nothing currently blocked |
| **Ordering Note** | This should be the first ADR any new contributor or agent reads |

## Context

### Problem Statement
The project needs a fixed engine, language, and physics/rendering stack before any
gameplay system can be designed or implemented, and needs an explicit policy for
handling the gap between "engine version the project builds on" (4.7) and "engine
version knowledge the assisting LLM reliably has" (a lagging, model-dependent
cutoff).

### Constraints
- Solo/small-team project — no bandwidth for maintaining custom engine builds or
  GDExtension modules.
- Target hardware: laptop-class iGPU, 1920×1080, ≥60 FPS.
- Windows-only target for now (no cross-platform requirement driving engine choice).

### Requirements
- Must support real-time first-person 3D movement, physics, and rendering.
- Must be free/open engine (no licensing cost constraint driving design).
- Must minimize risk of the assisting LLM confidently generating APIs that don't
  exist in the pinned version, or that have changed since its training cutoff.

## Decision

- **Engine**: Godot 4.7, Forward+ renderer.
- **Language**: GDScript only — no C#, no GDExtension, no third-party addons.
- **Physics**: Jolt Physics (Godot 4.7's default/selectable physics backend).
- **Graphics driver**: D3D12 on Windows.
- **API compatibility floor**: only API stable since **Godot 4.2**, even though
  the project builds on 4.7. This is the project's chosen mitigation for the
  engine-version-vs-LLM-knowledge gap — rather than maintaining a full
  breaking-changes/deprecated-APIs reference set via web research (the standard
  `/setup-engine` path for post-cutoff engines), the project simply avoids the
  post-4.2 API surface entirely. See `docs/engine-reference/godot/VERSION.md`.
- **Target**: Desktop only, 1920×1080, ≥60 FPS on a laptop iGPU.

## Alternatives Considered

### Alternative 1: Unity or Unreal
- **Description**: Use a more heavyweight commercial engine.
- **Pros**: More mature C# (Unity) or Blueprint/C++ (Unreal) tooling; larger
  asset ecosystems.
- **Cons**: Neither engine's default workflow matches "single GDScript-only
  scripting layer, no addons" as directly as Godot; both carry more licensing/
  build-pipeline overhead for a solo project.
- **Rejection Reason**: Godot's node/scene/signal model and GDScript's static
  typing were judged the best fit for a small, tightly-scoped simulation game;
  no requirement in the concept needs Unity/Unreal-specific systems (no AAA
  rendering pipeline, no asset-store dependency).

### Alternative 2: Full engine-reference research pack (breaking-changes.md, deprecated-apis.md, etc.) instead of the 4.2 floor
- **Description**: Do the full `/setup-engine` post-cutoff research path — web
  search official 4.3-4.7 migration guides and maintain a living breaking-changes
  document.
- **Pros**: Allows using newer APIs safely, with verified guidance.
- **Cons**: Ongoing maintenance burden disproportionate to project size; the
  4.2-floor policy achieves the same safety with zero maintenance cost, at the
  price of foregoing a few newer conveniences.
- **Rejection Reason**: The project has not yet hit a case where a 4.2 API was
  insufficient. If that changes, `/setup-engine refresh` is the documented
  escape hatch (see `docs/engine-reference/godot/VERSION.md`).

## Consequences

### Positive
- Every implementation task has one unambiguous stack to target — no per-system
  language or physics-backend decisions needed.
- The 4.2 API floor essentially eliminates the "LLM hallucinates a newer API"
  failure mode without any ongoing research burden.

### Negative
- Cannot use any genuinely new 4.3-4.7 feature even where it would be a clean fit,
  until this ADR is revisited.
- GDScript-only forecloses performance-critical GDExtension/C++ escape hatches —
  acceptable at current scope (simulation/puzzle game, not an engine-bound genre).

### Risks
- **Godot 4.7 may have subtle API differences from 4.4** (documented as R-06 in
  ТЗ-000) — mitigated by the 4.2 floor and by pinning `config/features` in
  `project.godot`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| design/gdd/game-concept.md | Technical Considerations section defers to this pin | Establishes the concrete engine/language/physics/target values referenced there |
| design/gdd/000-igrovoe-okruzhenie.md | NFR-04/NFR-05 (static typing, code style) | Same GDScript-only, static-typing convention this ADR fixes project-wide |

## Performance Implications
- **CPU/Memory**: N/A at the ADR level — governed by per-system NFRs (e.g. ТЗ-000
  NFR-01: ≥60 FPS, NFR-09: ≤200,000 triangles/scene, ≤50MB assets).
- **Load Time**: N/A.
- **Network**: N/A (single-player, no networking planned).

## Migration Plan
N/A — this is the project's original stack choice, made before any code existed.

## Validation Criteria
- Project opens in the Godot editor with zero errors/warnings (NFR-10, ТЗ-000).
- No `.cs`, no GDExtension `.gdextension` files, no addon folders ever appear in
  `addons/` — checked ad hoc during code review, not currently automated.

## Related Decisions
- ADR-0004 (no-autoloads convention + MCP tooling architecture)
- CLAUDE.md "Tech stack and constraints" section (this ADR formalizes what was
  already written there)
