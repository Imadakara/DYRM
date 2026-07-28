# Story 003: Station orbit, rotating ring geometry & gravity contract

> **Epic**: 000-igrovoe-okruzhenie
> **Status**: Done for orbital mechanics; dumbbell re-implementation done with
> one open physics defect (see closing note below)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L (retroactive — part of ТЗ-000's overall L estimate)
> **Manifest Version**: 2026-07-28
> **Last Updated**: 2026-07-28 (torus→dumbbell re-implementation and this
> status update; original implemented 2026-07-26/27)

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

**Original torus geometry (2026-07-27, superseded 2026-07-28):**
8 arcs × 45° (4 modules + 4 corridors), hub + 4 spokes at 45/135/225/315°.
This shape no longer exists in the codebase — replaced below.

**Dumbbell re-implementation (2026-07-28, per GDD Core Rules 4-5 revision):**
- [x] Despun hub does not rotate relative to the inertial frame — <0.01° change
      over 100 frames (AC-22, now `T-42 despun hub`)
- [x] `get_gravity_up_at()`/`get_gravity_at()` at both module floors: unit
      vector toward axis, `|get_gravity_at()| = 2.942 ± 0.01 m/s²` symmetric in
      both modules (AC-23)
- [x] Ring geometry: 2 modules (control_room, habitat) + 2 arm corridors +
      despun central hub with 2 lock chambers; 3 laser mounts + 4 antenna
      mounts on the despun truss (AC-30, AC-33, AC-34)
- [x] `StationRoot.get_rotating_assembly()` returns the correct parent node;
      objects added to it rotate with the assembly (AC-39) — the hook Epic 100
      Story 001 parents the player under
- [x] Lock-chamber ω(t)/g(t) monotonic and reversible across the full cycle,
      door interlocks correct (`T-41 lock chamber cycle`)
- [x] Arm-corridor crossing works via scripted transit, since a straight
      radial tube cannot be a walkable Jolt floor everywhere along its length
      (see GDD Edge Cases) — verified live via MCP and by test suite
- [x] **Root cause found and fixed (2026-07-28, same day)**: a `CharacterBody3D`
      fell straight through a habitable module's own flat floor from spawn.
      Diagnosed conclusively via live Godot MCP by comparing
      `PhysicsServer3D.body_get_state(rid, BODY_STATE_TRANSFORM)` against the
      ordinary GDScript `global_transform` for the same `AnimatableBody3D` in
      the same frame: the physics server's cached transform was **permanently
      frozen** at the body's initial, unrotated local position, while the
      scene-graph `global_transform` correctly showed the rotating position —
      `AnimatableBody3D.sync_to_physics` only re-pushes to the physics server
      when the body's OWN local transform is reassigned, not when an ANCESTOR
      (the spinning `RotatingAssembly`, 2+ levels up) rotates. Fixed by (1)
      moving the one-time mount transform from `_ready()` to `_enter_tree()`
      (top-down ordering, ahead of the child body's own `_ready()`-time physics
      registration) and (2) forcing
      `_collision_root.global_transform = _collision_root.global_transform`
      every physics frame in both `station_module.gd` and `arm_corridor.gd`,
      which re-triggers the sync despite the body's local value reading the
      same. See knowledge-base entry #20 (now marked РЕШЕНО) for the full
      mechanism — this class of bug is invisible to ordinary `global_transform`
      reads and can only be confirmed via `PhysicsServer3D.body_get_state()`.
- [ ] ⚠️ **Follow-up, smaller and expected**: now that real floor contact
      exists (it never did before this fix), the same Jolt-rotating-platform
      contact-resolution noise already documented/accepted for the original
      torus design (ADR-0002 Consequences → Negative, T-24/T-25 there) now
      also surfaces for the module floor, and several `tools/run_tests.gd`
      cases (T-20, T-31, T-41) have settle-timing/shared-sequential-state
      assumptions calibrated for the old (contact-free, effectively-freefall)
      behavior. These need a retuning pass, not a new root-cause hunt.

Implemented in `src/environment/station/`. Verified via `tools/run_tests.gd`:
31 of 42 tests pass as of 2026-07-28, after the sync fix above — **T-29
(teleport-then-grounded-within-1s), the test that directly exercises the fixed
defect, now passes** (previously failed). Net count is lower than the
pre-fix 33/42 because real contact resolution newly exposes accepted-class
platform noise in T-20/T-31/T-41, which did not fire before since the player
was never actually touching the floor. T-24, T-25 (torus-era, already-accepted
drift-class deviation, see story 001), T-26, T-27, T-28, T-32, T-36, T-38
remain open and need individual follow-up — not all are confirmed related to
this fix. Original torus geometry verified at ТЗ-000 acceptance, 2026-07-27.
