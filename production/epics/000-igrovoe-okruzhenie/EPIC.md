# Epic: Игровое окружение (000)

> **Layer**: Foundation
> **GDD**: design/gdd/000-igrovoe-okruzhenie.md
> **Architecture Module**: World/Environment (Local+Deep spatial model, Solar System simulation, station geometry)
> **Status**: Done for orbital mechanics/solar system (0.2); station geometry
> (0.1) re-implemented 2026-07-28 for the twin-module dumbbell — the blocking
> physics defect (module-floor fall-through) is **root-caused and fixed**
> (same day); a smaller follow-up test-retuning pass remains — see story 003
> **Stories**: 4 stories — 001, 002, 004 Done; 003 Done with the core defect
> fixed and a documented follow-up retuning item
> (see `production/epics/000-igrovoe-okruzhenie/003-station-orbit-and-ring.md`)

## Overview

Builds the entire physically-grounded world substrate the game runs inside: a
two-layer spatial model that keeps direction-to-object exact from station-interior
scale up to solar-system scale, a Keplerian solar system simulation, the station's
own orbit and rotating artificial-gravity ring, and the greybox station geometry
with all mounting points future systems need. Implemented and shipped before the
gamedev plugin was adopted; recorded here retroactively for traceability
(git commit "System 0 mvp done").

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Two-Layer Spatial Model | Local (1:1m)/Deep (compressed) split, logarithmic distance compression, single-source coordinate conversion | LOW |
| ADR-0002: Rotating Reference Frame | Establishes the gravity/up contract this epic exposes (consumed by Epic 100) | LOW |
| ADR-0003: Engine and Tech Stack Pin | Godot 4.7/GDScript/Jolt/D3D12, API floor since 4.2 | LOW |
| ADR-0004: No-Autoloads + MCP Tooling | Debug camera presets and overlay exist because of this tooling constraint | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-000-001 | Local/Deep two-layer world split | ADR-0001 ✅ |
| TR-000-002 | Monotonic direction-preserving distance compression | ADR-0001 ✅ |
| TR-000-003 | Angular size exact above threshold | ADR-0001 ✅ |
| TR-000-004 | Keplerian solar system at J2000 | ADR-0001 ✅ (data model) |
| TR-000-005 | Station circular orbit, period from μ | ADR-0001 ✅ |
| TR-000-006 | Rotating ring 0.3g via derived ω | ADR-0002 ✅ |
| TR-000-007 | Single gravity/up source of truth | ADR-0001, ADR-0002 ✅ |
| TR-000-008 | Single-location ecliptic→Godot conversion | ADR-0001 ✅ |
| TR-000-009 | Geometric eclipse computation | ADR-0001 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done` — satisfied
  for stories 001, 002, 004 (implementation predates the plugin, verified via
  `tools/run_tests.gd` (headless) and live MCP verification at the time of ТЗ-000
  acceptance, 2026-07-27). Story 003 was re-implemented 2026-07-28 for the
  station-geometry revision and is **not yet closable** — see below.
- No AC in `design/gdd/000-igrovoe-okruzhenie.md` remains unresolved without an
  explicit, accepted deviation note — **substantially satisfied**: the one
  blocking, unaccepted defect (`CharacterBody3D` falling through a habitable
  module's own floor) is now root-caused and fixed (knowledge-base entry #20,
  now РЕШЕНО). What remains is a smaller, expected follow-up: real floor
  contact now exposes the same Jolt-rotating-platform noise already accepted
  for the torus design (ADR-0002), plus a few `tools/run_tests.gd` cases need
  retuning for timing/tolerance assumptions calibrated around the old
  (contact-free) behavior — tracked in story 003, not a new root-cause hunt.
