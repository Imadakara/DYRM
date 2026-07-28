# Design Change Impact Report — `design/gdd/000-igrovoe-okruzhenie.md`

> **Date**: 2026-07-28
> **Trigger**: Station geometry revision — closed torus (8 arcs × 45°, 4
> modules, hub+spokes co-rotating with the ring) → twin-module rotating
> dumbbell (control room + habitat, symmetric, R=60m) with a **despun central
> hub** and a new lock-chamber frame-crossing mechanic. Authored via
> `/design-system` (lean review mode), consulting `systems-designer` (Formulas)
> and `qa-lead` (Acceptance Criteria).
> **Run via**: `/propagate-design-change design/gdd/000-igrovoe-okruzhenie.md`

## Change Summary

**Changed sections**: Status header, Overview, Player Fantasy (wording), Core
Rules (Rule 4 replaced, new Rule 5 inserted, Rules 6-8 renumbered), Interactions
with Other Systems (wording + new Block 3 row), Formulas (`[ring-artificial-
gravity]` reframed, two new formulas `[arm-corridor-length]` and
`[lock-chamber-spin-sync]`), Edge Cases (2 new, 1 reworded), Dependencies
(wording), Tuning Knobs (1 reworded, 2 new), Visual/Audio Requirements (2 new
bullets), Acceptance Criteria (2 reworded, 7 new, closing note replaced),
Open Questions (Q-02 closed, Q-05/Q-06 added).

**Unchanged sections**: UI Requirements; Core Rules 1-3; Formulas
`[distance-compression]`, `[visible-angular-size]`, `[station-orbit-period]`,
`[eclipse-shadow-arc]`; most Edge Cases (epoch rewind, axis singularity,
angular-diameter threshold, eclipse).

**Key changes affecting architecture:**
1. The rotating-reference-frame model changed structurally: previously the
   *entire* ring+hub+spokes co-rotated as one rigid body, only the *external*
   truss was despun. Now the **central hub is despun** while modules+arms
   rotate around it.
2. A brand-new mechanic (lock-chamber frame crossing) has no prior
   architectural decision — new territory, not a parameter revision.
3. Concrete numbers ADR-0002 cited (376.99m full lap, 8 arc floor points,
   16-chord floor segments) are now stale for this geometry.

## Impact Analysis — 4 ADRs reference this GDD

### ADR-0001: Two-Layer Spatial Model — ✅ Still Valid
References GDD 000 for the Local/Deep coordinate split and distance-compression
formula (Core Rule 1, unchanged). Station shape has no bearing on this.

### ADR-0002: Rotating Reference Frame — 🔴 Likely Superseded → **Resolved: updated in place**
**What the ADR assumed**: player is child of `RotatingRing`; hub+spokes
co-rotate with the ring; only the external truss is despun. Concrete numbers:
376.99m lap, 8 arc floor points, 16-chord floor segments.
**What the GDD now says**: hub is despun (Core Rule 4); new lock-chamber
frame-crossing mechanic (Core Rule 5, `[lock-chamber-spin-sync]`) has no
precedent in the ADR.
**Assessment**: Directly contradicts the ADR's central claim (what co-rotates
with what) and introduces an unaddressed new problem. The child-of-rotating-
node and no-Coriolis principles remain sound and were carried forward.
**Resolution** (user chose "update in place" over writing a new ADR):
- Title/Status/Date updated to record the 2026-07-28 revision
- Requirements: full-lap requirement replaced with the new linear route +
  new frame-crossing requirement
- Decision: new `RotatingAssembly` / `DespunHub` / `LockChamber` three-node
  model, with the player re-parented at each door threshold (reusing GDD 100's
  existing `teleport_to_module()` primitive)
- Architecture Diagram: fully redrawn
- Key Interfaces: added `LockChamber.begin_cycle()`/`get_omega()`/
  `is_synced_with_target()`, `StationRoot.get_despun_hub()`/
  `get_rotating_assembly()`
- New Alternative 3 added (continuous frame-blend crossing — rejected, would
  reopen the exact physics-stability problem this ADR exists to avoid)
- Consequences/Risks: old drift numbers explicitly flagged as torus-specific
  and unverified for the new geometry; two new risks added (lock-chamber pacing
  cost, three-way re-parent transform continuity)
- GDD Requirements Addressed table: updated rule numbers, two new rows added
- Migration Plan: written (was N/A) — this is the project's first real ADR
  migration
- Validation Criteria: flagged AC-06/AC-07 (GDD 100) as stale pending that
  GDD's own propagation pass; added pointer to GDD 000's new criteria set

### ADR-0003: Engine/Tech Stack Pin — ✅ Still Valid
References GDD 000 only for NFR-04/05 (static typing, GDScript-only) —
orthogonal to station geometry.

### ADR-0004: No Autoloads / MCP Tooling — ✅ Still Valid
References GDD 000 only for debug-tooling requirements (named camera presets,
programmatic debug twins) — unaffected by shape change.

## Beyond this skill's built-in ADR scope

Not part of `/propagate-design-change`'s checklist (ADRs only), but found while
reading around the impact:

- **`docs/architecture/tr-registry.yaml`, TR-000-006**: wording ("Rotating
  habitat ring... ring radius") is now stale terminology, though the
  underlying requirement (0.3g via centripetal acceleration, ω derived not
  hardcoded) is still true. Not edited here — recommend refreshing when the
  replacement ADR content is re-run through `/architecture-review`.
- **`docs/architecture/control-manifest.md`, line 27**: "Player parented under
  `RotatingRing`; velocity math in ring-local space — source: ADR-0002" is
  generated *from* ADR-0002 and is now stale in the same way ADR-0002 was.
  Since this file is produced by `/create-control-manifest`, re-running that
  skill after this revision is the natural fix — not hand-edited here.
- **`design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`** still describes "8
  arcs," "8 doors," "spokes locked" — this is a separate GDD, out of scope for
  a propagation run scoped to GDD 000. Needs its own
  `/propagate-design-change design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`
  pass (that GDD references ADR-0002 too, so re-running propagation there will
  re-surface ADR-0002, now already updated).
- **`production/epics/000-igrovoe-okruzhenie/003-station-orbit-and-ring.md`**
  (story, Status: Done) still implements the old torus. Re-implementation is
  required before any of this is playable — flagged as an explicit "open
  discrepancy" in GDD 000's Acceptance Criteria closing note.

## Traceability Index

`docs/architecture/architecture-traceability.md` does not exist in this
project (it uses `tr-registry.yaml` + `docs/registry/architecture.yaml`
instead) — step 8 of this skill was skipped per its own "if it exists"
condition.

## Follow-Up Actions

- Run `/propagate-design-change design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`
  once that GDD's own station-geometry references are revised.
- Run `/architecture-review` after GDD 100's propagation pass to verify the
  full traceability matrix is coherent again (ADR-0002 was updated in place,
  not left Superseded, so this is a consistency check, not a re-linking task).
- Re-run `/create-control-manifest` to refresh the now-stale line referencing
  the old `RotatingRing` pattern.
- Before starting implementation: re-run story
  `003-station-orbit-and-ring.md` (or a new story under Epic 000) against the
  revised GDD 000 + ADR-0002 — this is a full re-implementation of the station
  geometry, not a patch.

**Verdict: COMPLETE** — change impact report saved.
