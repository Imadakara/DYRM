# Story 002: Universal interaction contract — doors & spoke hatches

> **Epic**: 100-igrok-i-stancia-ot-pervogo-lica
> **Status**: Done (documented gap in geometry, not in this story's own logic)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (retroactive — part of ТЗ-100's overall L estimate)
> **Manifest Version**: 2026-07-28
> **Last Updated**: 2026-07-28 (retroactive record; implemented 2026-07-27)

## Context

**GDD**: `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`
**Requirement**: `TR-100-004`

**ADR Governing Implementation**: ADR-0004: No Autoloads + MCP Tooling (pattern
reference — `Interactable` is a GDD-level contract, not an ADR-level decision, but
follows the same "no type-specific special-casing" architectural discipline)
**ADR Decision Summary**: N/A architecture decision beyond the pattern itself —
see `design/gdd/100-...md` Core Rules 5–6 for the contract definition.

**Engine**: Godot 4.7 | **Risk**: LOW
**Engine Notes**: None.

**Control Manifest Rules (this layer)**:
- Required: `Interactable` base contract (`can_interact()`, `interact()`) for every interactive object
- Forbidden: `InteractionProbe` must not contain type-specific checks

---

## Acceptance Criteria

*From GDD `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`, scoped to this story:*

- [x] Interaction ray (2.0 m from screen center) finds a target and shows a
      non-empty prompt at 1.5 m, finds nothing at 2.5 m (AC-30)
- [x] `Door`, `SpokeHatch`, `WorkPanel` all inherit `Interactable`;
      `InteractionProbe` contains no type-specific checks (AC-31)
- [x] Door: `trigger_interact()` toggles open/closed, collision toggles, signal
      emitted (AC-32)
- [x] Spoke hatch: `trigger_interact()` never opens it, gives a refusal prompt, no
      `activated` signal (AC-33)
- [ ] ⚠️ **Known gap (geometry, not this story's logic)**: arc-seam openings have
      no end wall — the opening spans the full 7×3.5 m tube cross-section, while
      the door leaf (1.6×2.3 m) is human-scale. The door itself works correctly
      when interacted with directly, but doesn't physically block the opening —
      walking around it costs nothing. Inherited from station geometry (000);
      consciously deferred by user decision during the implementation session
      ("не трогать пока"), not reworked by this story. Causes T-36 to fail (a
      walk-toward-`control_deck`-spawn test never encounters a door within 2m/1000
      frames).

Implemented in `src/interaction/` (`Interactable`, `InteractionProbe`, `Door`,
`SpokeHatch`). Verified via `tools/run_tests.gd` (T-32, T-33, T-36 range) at
ТЗ-100 acceptance, 2026-07-27.
