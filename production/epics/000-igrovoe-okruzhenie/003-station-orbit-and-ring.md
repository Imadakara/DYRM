# Story 003: Station orbit, rotating ring geometry & gravity contract

> **Epic**: 000-igrovoe-okruzhenie
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L (retroactive — part of ТЗ-000's overall L estimate)
> **Manifest Version**: 2026-07-28
> **Last Updated**: 2026-07-28 (retroactive record; implemented 2026-07-26/27)

## Context

**GDD**: `design/gdd/000-igrovoe-okruzhenie.md`
**Requirement**: `TR-000-005`, `TR-000-006`, `TR-000-007`

**ADR Governing Implementation**: ADR-0002: Rotating Reference Frame
**ADR Decision Summary**: The station's ring rotates at an angular velocity
*derived* from a target gravity and radius (not hardcoded); `get_gravity_up_at()`/
`get_gravity_at()` on `StationRoot` is the single source of truth every future
consumer (starting with Epic 100) must use, never reimplement.

**Engine**: Godot 4.7 | **Risk**: LOW
**Engine Notes**: Pure geometry/math + greybox mesh generation — no engine-
version-sensitive API.

**Control Manifest Rules (this layer)**:
- Required: `StationRoot.get_gravity_up_at()`/`get_gravity_at()` as the sole gravity/up source
- Forbidden: never give a system its own gravity/up computation
- Forbidden: never simulate the Coriolis force

---

## Acceptance Criteria

*From GDD `design/gdd/000-igrovoe-okruzhenie.md`, scoped to this story:*

- [x] Station orbital period = 75,991 ± 10 s at radius 100,000 ± 1 km, period
      derived from Neptune's μ, not hardcoded (AC-20)
- [x] Ring rotation: 360° ± 0.1° over 28.375 game-seconds (AC-21)
- [x] Despun truss (ferма with lasers/antennas) does not rotate relative to the
      inertial frame — <0.01° change over 100 frames (AC-22)
- [x] `get_gravity_up_at()` at 8 arc floor points: unit vector toward axis,
      `|get_gravity_at()| = 2.942 ± 0.01 m/s²` (AC-23)
- [x] Ring geometry: 8 arcs × 45° (4 modules + 4 corridors), hub + 4 spokes at
      45/135/225/315°, 3 laser mounts + 4 antenna mounts on the despun truss (AC-30, AC-33, AC-34)
- [x] `StationRoot.get_rotating_ring()` returns the correct parent node; objects
      added to it rotate with the ring (AC-39) — this is the exact hook Epic 100
      Story 001 parents the player under
- [x] 8 spawn points, 7 named panel mounting markers, 4 spoke-hatch markers, all
      within mounting-height constraints (AC-37, AC-40)

Implemented in `src/environment/station/`. Verified via `tools/run_tests.gd` at
ТЗ-000 acceptance, 2026-07-27.
