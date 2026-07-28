# Story 004: Debug camera, overlay & MCP tooling scaffolding

> **Epic**: 000-igrovoe-okruzhenie
> **Status**: Done
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: M (retroactive — part of ТЗ-000's overall L estimate)
> **Manifest Version**: 2026-07-28
> **Last Updated**: 2026-07-28 (retroactive record; implemented 2026-07-26/27)

## Context

**GDD**: `design/gdd/000-igrovoe-okruzhenie.md`
**Requirement**: (tooling infrastructure — no dedicated TR-ID; supports every
other requirement's verifiability)

**ADR Governing Implementation**: ADR-0004: No Autoloads + Godot MCP Tooling Bridge
**ADR Decision Summary**: Named, deterministic camera presets and a scene-tree-
mirrored debug overlay exist specifically because MCP-driven verification (both
headless and live-bridge) needs a repeatable way to reach a specific view and
read state without physical input.

**Engine**: Godot 4.7 | **Risk**: LOW
**Engine Notes**: None beyond standard `Camera3D`/`CanvasLayer` APIs.

**Control Manifest Rules (this layer)**:
- Required: named, deterministic camera angles switchable in code
- Required: diagnostics mirrored into the live scene tree, not `print()`-only

---

## Acceptance Criteria

*From GDD `design/gdd/000-igrovoe-okruzhenie.md`, scoped to this story:*

- [x] Free debug camera (WASD + mouse, Shift = boost) (AC-50, AC-62)
- [x] 5 named presets (`1`–`5`: external view, from rubka, toward Neptune, toward
      Sun, ferма close-up), each reachable via `go_to_preset(n)` with matching
      `current_preset()` readback (AC-50)
- [x] Debug overlay (`F3`): FPS, `epoch_days`, `time_scale`, station position,
      ring rotation angle, per-body distance/azimuth/elevation/angular diameter,
      all readable from named `Label` nodes matching public getters (AC-51)
- [x] `[`/`]` change `time_scale` (1×…1,000,000×), `P` pauses time, all with
      programmatic equivalents (AC-52)
- [x] ≥60 FPS at 1920×1080 in all 5 presets (AC-61)
- [x] Project validates and runs with zero errors/warnings (AC-60, NFR-10)

Implemented in `src/core/` (`DebugFlyCamera`, `DebugOverlay`, `GameClock`).
Verified via `tools/run_tests.gd` and live MCP runtime verification at ТЗ-000
acceptance, 2026-07-27.
