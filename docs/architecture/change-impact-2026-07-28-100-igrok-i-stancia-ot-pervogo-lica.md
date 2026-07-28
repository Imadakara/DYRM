# Design Change Impact Report — `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`

> **Date**: 2026-07-28
> **Trigger**: Propagation follow-up to the station geometry revision in
> `design/gdd/000-igrovoe-okruzhenie.md` (see
> `change-impact-2026-07-28-000-igrovoe-okruzhenie.md`). GDD 100 itself had not
> been edited when `/propagate-design-change` was first invoked on it — its
> content was stale *by dependency*, not by its own edit. Per user decision,
> GDD 100 was revised first (this document), then propagated.
> **Run via**: `/propagate-design-change design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`

## Change Summary

**Changed sections**: Status header (flags station-geometry-dependent parts —
spawn/teleport targets, door topology, hub-lock interaction — as stale pending
re-implementation, distinct from the still-Complete player-controller/panel
framework); Overview (wording); Core Rule 1 (rotating parent generalized to
`RotatingAssembly`/`LockChamber`/`DespunHub` instead of hardcoded
`RotatingRing`); Core Rule 3 (spawn/teleport targets: 8 arcs → 3 named
locations — `control_room`, `habitat`, `hub`); Core Rule 6 (doors: 8→6 per
GDD 000's Q-05; spoke hatches → Block 3 hub end-face attachment points);
States/Transitions (hub end-face lock row reworded, new lock-chamber-door row
added); Interactions with Other Systems + Dependencies (wording, added
`get_despun_hub()`); Formulas `[ring-up-direction]` (variable description
generalized to "current parent," math untouched); Edge Cases (2 new — Block 3
lock wording, lock-chamber-not-synced cross-reference to 000; 1 reworded —
"вращающейся сборки" instead of "кольца"); Acceptance Criteria (376.99m
full-lap test retired — no longer a closed loop; radius/support test rescoped
to standing inside a module; new monotonic-radius-along-arm criterion added;
door test updated to new topology; honest "design-ahead-of-code" caveat added
matching GDD 000's); Open Questions (Q-03 reworded: "spokes" → hub end-face
attachment points).

**Unchanged**: Player Fantasy; Core Rules 2, 4, 5, 7 (basis reorientation,
mouse look, universal interaction, work panel framework); Formulas
`[player-basis-reorientation]`, `[reduced-gravity-jump]`,
`[panel-hitpoint-to-pixel]`, `[interactive-element-angular-size]`; Tuning
Knobs; Visual/Audio Requirements; UI Requirements; Open Question Q-01.

## Impact Analysis — 2 ADRs reference this GDD

### ADR-0002: Rotating Reference Frame — ✅ Still Valid (no new edit needed)
**What the ADR assumed**: Its GDD Requirements Addressed table already reads
(from the prior propagation pass, same day): "Player must be a child of the
rotating parent; velocity math in its local space (Core Rule 1) — ...now onto
`RotatingAssembly` instead of the old `RotatingRing`."
**What the GDD now says**: Core Rule 1 was just revised to say exactly this —
"дочерний узел вращающейся сборки (или лок-камеры/неподвижной ступицы во время
перехода — см. 000 ADR-0002)."
**Assessment**: The ADR-0002 update made during the *previous* propagation
pass (on GDD 000) already anticipated and pre-satisfied this exact GDD 100
wording change. No further action needed — this is a confirmation, not a new
finding.

### ADR-0004: No Autoloads / MCP Tooling — ✅ Still Valid
References GDD 100 only for FR-50 (every debug key binding needs a
programmatic twin) — completely orthogonal to station geometry, untouched by
this revision.

## Resolution

No ADRs required resolution — both are Still Valid. `lean` review mode →
TD-CHANGE-IMPACT gate skipped, consistent with the GDD 000 pass.

## Traceability Index

`docs/architecture/architecture-traceability.md` does not exist in this
project (see the GDD 000 change-impact report for the same note) — step 8
skipped per its own "if it exists" condition.

## Remaining Known Gaps (carried forward, not new)

- `src/player/`, `src/interaction/` still implement the old torus's 8-arc
  spawn/teleport targets and 8-door topology — re-implementation required
  alongside GDD 000's station geometry (tracked in that GDD's Acceptance
  Criteria closing note, not duplicated here).
- `production/epics/100-igrok-i-stancia-ot-pervogo-lica/*.md` stories will
  need their own acceptance-criteria refresh once re-implementation is
  scheduled — not part of this GDD-level propagation pass.

**Verdict: COMPLETE** — change impact report saved.
