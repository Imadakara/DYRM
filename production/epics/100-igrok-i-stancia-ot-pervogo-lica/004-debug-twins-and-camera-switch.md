# Story 004: Debug input twins & camera switch

> **Epic**: 100-igrok-i-stancia-ot-pervogo-lica
> **Status**: Done (one requirement not implemented — see below)
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: S (retroactive — part of ТЗ-100's overall L estimate)
> **Manifest Version**: 2026-07-28
> **Last Updated**: 2026-07-28 (retroactive record; implemented 2026-07-27)

## Context

**GDD**: `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`
**Requirement**: `TR-100-007`, `TR-100-008`

**ADR Governing Implementation**: ADR-0004: No Autoloads + Godot MCP Tooling Bridge
**ADR Decision Summary**: Every debug-bound input needs a public programmatic
twin, and the debug/player camera needs a programmatic switch — both exist
because MCP-driven verification runs backgrounded/headless, where physical input
and window focus aren't available.

**Engine**: Godot 4.7 | **Risk**: LOW
**Engine Notes**: `Camera3D.current` property switch — stable since 4.2; the gap
below is a missed implementation, not an engine limitation.

**Control Manifest Rules (this layer)**:
- Required: every debug-bound input has a public programmatic twin method
- Required: named, deterministic camera angles switchable in code

---

## Acceptance Criteria

*From GDD `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`, scoped to this story:*

- [x] All player commands bound to keys/mouse have public programmatic twin
      methods (`set_move_input`, `set_run_input`, `add_look_input`,
      `set_look_direction`, `trigger_jump`, `trigger_interact`,
      `teleport_to_module`) (AC-50)
- [x] `_unhandled_input`/`_poll_physical_input` only call these public methods —
      no movement logic lives in the input handler itself (AC-50)
- [x] Player block added to the debug overlay: current module, local position,
      radius, up, speed, grounded flag, interaction target (AC-52)
- [ ] ❌ **Not implemented** — programmatic switch between `DebugFlyCamera` and
      the player camera (FR-51/TR-100-008). No `current`-switching method or
      property exists in the codebase; both `Camera3D` nodes rely on Godot's
      default "first node in tree wins" behavior. Marked as a genuine gap (not a
      partial/deviation) — discovered during live verification, outside the
      original test list, but a real requirement this story owns. Left open for
      a follow-up story against this same epic if camera switching becomes
      needed for future verification work.

Implemented in `src/player/player_controller.gd`, `src/core/debug_overlay.gd`.
One additional defect found only by live verification and fixed within this
story's scope: `DebugOverlay` didn't set `mouse_filter`, so
`Control.MOUSE_FILTER_STOP` silently ate mouse-look input whenever the invisible
captured cursor sat over the overlay — fixed by recursively setting
`MOUSE_FILTER_IGNORE` on the overlay and the interaction crosshair. See
`design/gdd/100-...md` and historical ТЗ-100 §16.2 for full detail.
