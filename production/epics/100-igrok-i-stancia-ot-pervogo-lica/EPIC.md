# Epic: Игрок и станция от первого лица (100)

> **Layer**: Foundation
> **GDD**: design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md
> **Architecture Module**: Player (locomotion, camera, interaction, work-panel framework)
> **Status**: Done (documented deviations — see stories 003/004)
> **Stories**: 4 stories, all Done — see `production/epics/100-igrok-i-stancia-ot-pervogo-lica/`

## Overview

Gives the player a physical body inside the station built by Epic 000: locomotion
and camera in the rotating ring's reference frame, a universal interaction
contract (doors, locked spoke hatches), and the `WorkPanel` framework that every
future rubka panel (021, 022, 024, 025, 027, 029, 039) will mount its content
into without modifying the panel's own code. Implemented and shipped before the
gamedev plugin was adopted; recorded here retroactively for traceability
(git commit "System 1 mvp done"). Several known deviations from spec were found
during live verification and accepted rather than blocking ship — see stories
below and `design/gdd/100-...md` Acceptance Criteria.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Rotating Reference Frame | Player as child of RotatingRing, ring-local velocity, no Coriolis | LOW |
| ADR-0001: Two-Layer Spatial Model | Player operates entirely within the Local layer | LOW |
| ADR-0004: No-Autoloads + MCP Tooling | WorkPanel content-injection pattern, programmatic debug twins | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-100-001 | Player child of RotatingRing, ring-local velocity | ADR-0002 ✅ |
| TR-100-002 | Continuous basis reorientation with degenerate fallback | ADR-0002 ✅ |
| TR-100-003 | No own gravity constant — consume 000's contract | ADR-0001, ADR-0002 ✅ |
| TR-100-004 | Interactable contract, 2.0m ray, distance gate | ADR-0004 (pattern) ✅ |
| TR-100-005 | WorkPanel SubViewport-to-mesh framework | ADR-0004 (pattern) ✅ |
| TR-100-006 | WorkPanel content injection without editing WorkPanel | ADR-0004 (pattern) ✅ |
| TR-100-007 | Programmatic twin for every debug input | ADR-0004 ✅ |
| TR-100-008 | Programmatic camera switch (DebugFlyCamera ↔ player) | ❌ Not implemented — known gap |
| TR-100-009 | No drift while standing/walking on rotating floor | ⚠️ Partially implemented — residual drift beyond tolerance |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done` — **satisfied
  retroactively with accepted deviations**: TR-100-008 (camera switch) is an open
  gap and TR-100-009 (drift) is a partial pass; both were consciously accepted at
  ship time rather than blocking (see `design/gdd/100-...md` §Acceptance Criteria,
  itself porting ТЗ-100 §16 "Итог реализации"). Any future rework of these two
  should go through a new story against this same epic, not silently patched.
