# Story 002: Solar system Keplerian simulation

> **Epic**: 000-igrovoe-okruzhenie
> **Status**: Done
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L (retroactive — part of ТЗ-000's overall L estimate)
> **Manifest Version**: 2026-07-28
> **Last Updated**: 2026-07-28 (retroactive record; implemented 2026-07-26/27)

## Context

**GDD**: `design/gdd/000-igrovoe-okruzhenie.md`
**Requirement**: `TR-000-004`, `TR-000-009`

**ADR Governing Implementation**: ADR-0001: Two-Layer Spatial Model (data model
consumed by this story; the Kepler-solving logic itself is a direct GDD
requirement rather than a separate architectural decision)
**ADR Decision Summary**: Positions must be a pure function of `epoch_days`, and
direction to any body must be exact — this story is what produces those
positions for the Deep-layer renderer built in Story 001.

**Engine**: Godot 4.7 | **Risk**: LOW
**Engine Notes**: Pure math (Newton's method for Kepler's equation) — no engine-
version-sensitive API involved.

**Control Manifest Rules (this layer)**:
- Required: positions are a pure function of `epoch_days` (determinism, NFR-08)
- Forbidden: no numeric literals except universal constants — orbital elements
  live in `CelestialBodyData`/`OrbitalElements` `.tres` resources

---

## Acceptance Criteria

*From GDD `design/gdd/000-igrovoe-okruzhenie.md`, scoped to this story:*

- [x] Sun + 8 planets + Triton modeled (`SolarSystem.get_bodies().size() == 10`) (AC-10)
- [x] Positions at `epoch_days = 0` match JPL SSD reference within ±0.01 AU per coordinate (AC-11)
- [x] Each body rotates with correct period/axial tilt, including retrograde Venus/Uranus (AC-12)
- [x] Triton: retrograde orbit around Neptune, inclination 156.885°, period 5.876854 days, tidally locked (AC-13)
- [x] `direction_from_station()` returns a unit vector with zero angular error vs. `(body_pos - station_pos)` (AC-14)
- [x] ≥3000-star procedural background, deterministic by seed (AC-16)
- [x] Position round-trip: `epoch_days = 1000` then back to `0` reproduces original position to 1e-6 (AC-18, determinism)
- [x] Station eclipse by Neptune computed geometrically — shadow arc ≈28.51° of orbit (AC-24)

Implemented in `src/environment/solar_system/`. Verified via `tools/run_tests.gd`
at ТЗ-000 acceptance, 2026-07-27.
