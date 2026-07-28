# Story 001: Player locomotion & camera in the rotating ring

> **Epic**: 100-igrok-i-stancia-ot-pervogo-lica
> **Status**: Done (documented deviation)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L (retroactive — part of ТЗ-100's overall L estimate)
> **Manifest Version**: 2026-07-28
> **Last Updated**: 2026-07-28 (retroactive record; implemented 2026-07-27)

## Context

**GDD**: `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`
**Requirement**: `TR-100-001`, `TR-100-002`, `TR-100-003`, `TR-100-009`

**ADR Governing Implementation**: ADR-0002: Rotating Reference Frame
**ADR Decision Summary**: Player is a child of `RotatingRing`; velocity is tracked
in ring-local space and converted to global once per frame around
`move_and_slide()`; gravity/up comes exclusively from `StationRoot` (000).

**Engine**: Godot 4.7 | **Risk**: LOW
**Engine Notes**: `CharacterBody3D`/`move_and_slide()`/Jolt contact resolution —
all stable since 4.2/4.3. The residual drift noted below is a physics-integration
tuning issue, not an engine API gap.

**Control Manifest Rules (this layer)**:
- Required: player parented under `RotatingRing`; velocity math in ring-local space
- Forbidden: never give a system its own gravity/up computation
- Forbidden: never simulate the Coriolis force

---

## Acceptance Criteria

*From GDD `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`, scoped to this story:*

- [x] `Player` node's parent is `RotatingRing`; `local_velocity` does not rotate
      with the ring (AC-01)
- [x] `get_up_direction()` matches reference vectors at 8 arc centers to <0.01°
      (AC-02)
- [x] Player basis stays orthonormal/right-handed across a full lap, with
      documented degenerate-case fallback (AC-03, AC-04)
- [x] Gravity magnitude applied matches `StationRoot.get_gravity_at()` to 1e-6; no
      own gravity constant in code (AC-05)
- [x] Walk (2.0 m/s) and run (3.6 m/s via Shift) with smooth accel/decel (AC-08)
- [x] Jump at 0.3g: height 0.680 ± 0.02 m, air time 1.360 ± 0.05 s (AC-09)
- [x] Spawn/teleport to any of 8 arcs, grounded within 1.0 s (AC-11)
- [ ] ⚠️ **Known deviation** — standing still 10s: drift should be <0.01 m;
      actual up to 0.87 m tangential drift observed (T-25). Full-lap azimuth
      should close within ±0.5°; actual ~4.8–4.9° divergence (T-24). Root cause:
      Jolt contact resolution against the rotating floor reintroduces tangential
      noise not fully cancelled by the radius-snap mitigation. See ADR-0002
      Consequences → Negative. **Accepted at ship time, not blocking.**
- [ ] ⚠️ Threshold-climbing (0.35 m should pass, 0.40 m should fail) — 0.40 m
      obstacle passes when spec says it shouldn't (T-28, softer than spec).

Implemented in `src/player/player_controller.gd`, `src/player/player_camera.gd`.
Verified via `tools/run_tests.gd` (T-20…T-31 range) plus live MCP verification
(`scenes/dev/movement_calibration.tscn`) at ТЗ-100 acceptance, 2026-07-27 — two
real defects found only by live verification (spawn-on-axis black screen,
positional "bounce" from Jolt drift) were fixed during that session; see full
detail in `design/gdd/100-...md` and the historical ТЗ-100 §16.1.
