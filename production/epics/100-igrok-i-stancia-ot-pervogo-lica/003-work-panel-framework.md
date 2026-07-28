# Story 003: Work panel framework + diagnostic panel

> **Epic**: 100-igrok-i-stancia-ot-pervogo-lica
> **Status**: Done
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L (retroactive — part of ТЗ-100's overall L estimate)
> **Manifest Version**: 2026-07-28
> **Last Updated**: 2026-07-28 (retroactive record; implemented 2026-07-27)

## Context

**GDD**: `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`
**Requirement**: `TR-100-005`, `TR-100-006`

**ADR Governing Implementation**: ADR-0004: No Autoloads + MCP Tooling (the
content-injection pattern this story implements is what lets each future panel
system — 021, 022, 024, 025, 027, 029, 039 — attach content without touching
`WorkPanel`'s own code, in the same spirit as the ADR's no-hidden-coupling stance)
**ADR Decision Summary**: See `design/gdd/100-...md` Core Rule 7 for the full
`WorkPanel` contract definition.

**Engine**: Godot 4.7 | **Risk**: LOW
**Engine Notes**: `SubViewport` render-to-texture-on-mesh and `push_input()` for
routing synthetic mouse events are stable since 4.2.

**Control Manifest Rules (this layer)**:
- Required: `WorkPanel` renders UI via `SubViewport` onto a flat mesh; content
  attached via `set_ui_scene()`/`get_ui_root()` without editing `WorkPanel` itself
- Performance guardrail: invisible/static `SubViewport`s must not redraw; total
  panel repaint cost ≤2ms/frame

---

## Acceptance Criteria

*From GDD `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`, scoped to this story:*

- [x] Panel surface 0.60×0.45 m at 1024×768 resolution, matching aspect ratio to 1e-9 (AC-40)
- [x] `surface_to_viewport()` matches reference points to 0.5px; out-of-surface hit
      returns (−1,−1) (AC-41)
- [x] Aiming + click on the diagnostic panel's button changes its state via real
      `SubViewport` input routing (AC-42) — verified live end-to-end
      (aim → click → button state `0 → 1`)
- [x] Exactly 7 mounted panels with correct IDs; all show `has_content() == false`
      with a stub naming the responsible future system (AC-43)
- [x] `set_ui_scene()` swaps content and restores the stub without modifying
      `WorkPanel`'s own code (AC-44)
- [x] Diagnostic panel fully functional: button, toggle, slider, text field (AC-45)
- [x] `request_input_capture(true)` suppresses player movement/look until released (AC-46)
- [x] Minimum interactive element ≥0.04×0.04 m; panels mounted 0.90–1.90 m height,
      0.8–1.5 m working distance (AC-47)
- [x] Invisible panels do not redraw their `SubViewport` (AC-48)

Implemented in `src/interaction/work_panel.gd` and the 7 mounted rubka panel
scenes. Verified via `tools/run_tests.gd` (T-33, T-34, T-42, T-45 range) plus live
MCP end-to-end verification at ТЗ-100 acceptance, 2026-07-27. This story's
acceptance criteria are fully passing — no deviations, unlike Stories 001 and 002.
