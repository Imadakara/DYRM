# Story 001: Two-layer spatial model & distance compression

> **Epic**: 000-igrovoe-okruzhenie
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L (retroactive — part of ТЗ-000's overall L estimate)
> **Manifest Version**: 2026-07-28
> **Last Updated**: 2026-07-28 (retroactive record; implemented 2026-07-26/27)

## Context

**GDD**: `design/gdd/000-igrovoe-okruzhenie.md`
**Requirement**: `TR-000-001`, `TR-000-002`, `TR-000-003`, `TR-000-008`

**ADR Governing Implementation**: ADR-0001: Two-Layer Spatial Model
**ADR Decision Summary**: Split the world into Local (1:1m, r=2000m) and Deep
(logarithmically compressed, separate SubViewport/World3D composited behind
without depth write) layers; direction is preserved exactly, only radial distance
is compressed; ecliptic→Godot conversion lives in exactly one place.

**Engine**: Godot 4.7 | **Risk**: LOW
**Engine Notes**: SubViewport/World3D compositing and camera rotation-copy are all
API stable since 4.2.

**Control Manifest Rules (this layer)**:
- Required: Two-layer world (Local 1:1m / Deep compressed, SubViewport composited behind)
- Required: Ecliptic→Godot conversion only in `SpaceScale.ecliptic_to_godot()`
- Forbidden: Never reimplement the ecliptic→Godot conversion outside `SpaceScale`

---

## Acceptance Criteria

*From GDD `design/gdd/000-igrovoe-okruzhenie.md`, scoped to this story:*

- [x] `compress_distance()` strictly monotonic across 1e3–1e10 km, matches
      reference table within 0.01 units (AC-04, ТЗ-000)
- [x] Direction between Local and Deep representations of the same body agrees to
      <0.001° (AC-05)
- [x] `render_radius()` matches reference table within 0.001 (AC-06)
- [x] Deep layer camera copies main camera rotation+FOV every frame without parallax drift (AC-03)
- [x] Deep layer composites behind Local with no z-fighting, no depth-buffer writes (AC-02)
- [x] Scale constants (`compression_k`, `compression_d0_km`, `min_angular_diameter_deg`) live in `SpaceScaleConfig.tres`, editable without code changes (AC-07)

Implemented in `src/environment/solar_system/space_scale_config.gd` and the Deep
viewport compositing setup under `src/environment/`. Verified via
`tools/run_tests.gd` (T-01…T-07 range) at ТЗ-000 acceptance, 2026-07-27.
