# ADR-0002: Rotating Reference Frame — Player as Child of the Rotating Assembly, Despun Hub, No Coriolis Simulation

## Status
Accepted (revised in place, 2026-07-28)

## Date
2026-07-27 (decided in ТЗ-000 v0.3 / ТЗ-100 v0.3; retrofitted into ADR format
2026-07-28 during gamedev plugin adoption — no new decision). **Revised
2026-07-28**: station geometry changed from a closed torus (hub+spokes
co-rotating with the ring, only the external truss despun) to a twin-module
rotating dumbbell with a **despun central hub** and a new lock-chamber
frame-crossing mechanic — see `design/gdd/000-igrovoe-okruzhenie.md` Core Rules
4-5. This is an in-place revision (same ADR number, per user decision during
`/propagate-design-change`), not a new ADR — the core "child of the rotating
node, no Coriolis" pattern this ADR established is carried forward onto the
new geometry; only the Decision, Diagram, Consequences and cross-references
below were updated to match.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 |
| **Domain** | Physics |
| **Knowledge Risk** | LOW — `CharacterBody3D`, `move_and_slide()`, Jolt as physics backend are all stable since 4.2/4.3 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Known residual drift under this approach is already documented — see Consequences → Negative and the linked GDD Acceptance Criteria deviations |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Local-layer coordinate convention) |
| **Enables** | All future systems that place objects in the ring (013 Жизнеобеспечение, 014 EVA, panels 021-039) |
| **Blocks** | None currently — Epic 100 already implements this |
| **Ordering Note** | Any future EVA/zero-g system (014) that needs to leave the ring's rotating frame must define its own explicit frame-transition contract; it does not reuse this ADR's frame directly |

## Context

### Problem Statement
The player must walk on the inside of a torus that physically rotates at
0.2214345 rad/s (period 28.375 s) to produce 0.3g artificial gravity. A naive
approach — player as a sibling of the ring, with gravity direction recomputed
per frame in global space — makes `move_and_slide()` fight the rotating parent:
the floor visually slides out from under the character at up to 13.29 m/s
(tangential velocity at r=60m), because Godot's physics resolves collision
response in global space each frame.

### Constraints
- Jolt Physics as the physics backend (project-wide pin, see ADR-0003).
- No custom physics engine or C++/GDExtension — GDScript only.
- Player must feel physically stable standing still and walking, in both
  directions around the ring.
- Coriolis force at this radius/speed is 30-54% of gravity at walking/running
  speed — physically real, but would make walking direction-dependent in a way
  that adds nothing to the game's fantasy (this is a signal-relay operator sim,
  not a physics-accuracy showcase).

### Requirements
- Player must stand stably on the rotating floor without visible jitter or drift.
- "Up" must be a pure function of position (`StationRoot.get_gravity_up_at()`
  from ADR-0001's Local layer), never a value the player controller invents itself.
- Must support walking the full one-way route (module → arm → lock chamber →
  hub → lock chamber → arm → module, ≈110-115 m per `[arm-corridor-length]` in
  GDD 000) without falling through geometry. **(Revised 2026-07-28**: no longer
  a closed 376.99 m lap — the station is a linear dumbbell, not a torus.)
- **(New 2026-07-28)** Must support a player physically crossing from the
  rotating assembly into the despun hub (and back) through a lock chamber,
  without inventing a discontinuous "up" vector or a visible teleport pop.

## Decision

The player (`CharacterBody3D`) is a **child node of the rotating assembly**
(2 modules + 2 arm-corridors — **no longer including the hub**, see Revision
below), and all velocity math is carried out in that node's own local
coordinate system — which is treated as inertial for the purposes of the
player controller. Velocity is converted to global space exactly once per
physics frame, immediately around the `move_and_slide()` call. Every frame,
the player's basis is re-orthonormalized against the current "up" direction
(from `StationRoot.get_gravity_up_at()`), while preserving the previous
frame's look direction — see the `ring-up-direction` and
`player-basis-reorientation` formulas in
`design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md` (shape-general, unaffected
by this revision).

**Coriolis force is explicitly not modeled** (inherited from ADR-0001's parent
assumption in ТЗ-000 A-03): the physically correct effect (30.1% of g at walking
speed, 54.2% at running speed) would make travel direction feel meaningfully
different depending on which way the player moves relative to the rotation,
which is parasitic complexity for a signal-relay operator game, not a
spaceflight-realism game.

### Revision 2026-07-28: Despun Hub + Lock-Chamber Frame Crossing

The station's central technical hub is now **despun** — fixed relative to the
inertial frame, like the external laser/antenna truss always was — rather than
co-rotating with the ring as in the original torus design. This makes the
rotating-frame boundary "rotating assembly vs. despun hub" instead of "ring
(incl. hub+spokes) vs. external truss only," and introduces a new problem this
ADR did not previously cover: **the player must physically cross that boundary
on foot**, through a walkable lock chamber at each arm↔hub junction (GDD 000
Core Rule 5, `[lock-chamber-spin-sync]`).

**Decision**: the lock chamber is its own node (`LockChamber`), distinct from
both the rotating assembly and the despun hub. Its own local rotation angle is
driven by numerically integrating `ω(t)` from `[lock-chamber-spin-sync]`
(GDD 000) — not by inheriting a parent's transform. The player is **re-parented
at each door threshold**, mirroring the discrete re-parent pattern GDD 100
already uses for `teleport_to_module()`:

1. Player is a child of `RotatingAssembly` while inside a module or arm corridor.
2. Crossing the near door re-parents the player to `LockChamber`. Its rotation
   angle at that instant matches `RotatingAssembly`'s current angle exactly (no
   pop) and then ramps toward 0 (or from 0, for the reverse direction) over the
   cycle. Movement input is suppressed for the full cycle duration (GDD 000
   Core Rule 5) — this is a deliberate simplification: a **discrete, scripted
   transition**, not continuous free locomotion across a spinning interface.
3. At `ω(t) = 0` (cycle complete), the far door unlocks; crossing it re-parents
   the player to `DespunHub`, which never rotates.
4. The reverse sequence runs symmetrically for hub → arm travel.

This generalizes the ADR's original pattern (basis reorthonormalized against
`get_gravity_up_at()`, one source of truth, never invented locally) onto a
third node type whose angular velocity is neither constant (`RotatingAssembly`)
nor zero (`DespunHub`), but a scripted function of time.

### Architecture Diagram
```
DespunHub (fixed, non-rotating relative to inertial frame)
  ├─ [future] Block 3 docking/functional modules (hub end-faces)
  └─ LockChamber A, LockChamber B (docked here when ω(t)=0)

RotatingAssembly (rotates continuously, angle = f(epoch_days), ω₀ = 0.2214345 rad/s)
  ├─ Module: Control Room (r=60m) ── Arm A ── [LockChamber A]
  ├─ Module: Habitat (r=60m)      ── Arm B ── [LockChamber B]
  └─ Player (CharacterBody3D), Door, WorkPanel — re-parented across
       RotatingAssembly ↔ LockChamber ↔ DespunHub at each door threshold
       local_velocity: Vector3   ← source of truth, current parent's local space
       (converted to global once per physics frame, around move_and_slide())

LockChamber A / B (own rotation = ∫ω(t) dt from [lock-chamber-spin-sync],
  GDD 000 — matches RotatingAssembly at cycle start, DespunHub (0) at cycle end)
```

### Key Interfaces
- `PlayerController.local_velocity: Vector3` (current parent's local space, source of truth)
- `StationRoot.get_gravity_up_at(p: Vector3) -> Vector3` (consumed, not reimplemented)
- `StationRoot.get_gravity_at(p: Vector3) -> Vector3` (consumed, not reimplemented)
- **(New)** `LockChamber.begin_cycle(direction: int)`, `LockChamber.get_omega() -> float`,
  `LockChamber.is_synced_with_target() -> bool` — drives/queries `[lock-chamber-spin-sync]`
- **(New)** `StationRoot.get_despun_hub() -> Node3D`, `StationRoot.get_rotating_assembly() -> Node3D`
  (`get_rotating_ring()` from the original decision is likely renamed during
  re-implementation — not decided here, flagged for the eventual dev-story)

## Alternatives Considered

### Alternative 1: Player as sibling of the ring, gravity applied in global space
- **Description**: Keep player outside the `RotatingRing` hierarchy; recompute
  "down" in global space every frame and apply it directly.
- **Pros**: Conceptually simpler node hierarchy.
- **Cons**: `move_and_slide()` fights the rotating floor every frame — the floor
  moves out from under the character in global space, producing visible sliding
  and instability.
- **Rejection Reason**: Confirmed unstable during design; this is the exact
  failure mode the chosen approach exists to avoid.

### Alternative 2: Full Coriolis simulation
- **Description**: Model the Coriolis pseudo-force explicitly so walking
  clockwise vs. counter-clockwise around the ring feels physically different.
- **Pros**: Physically complete simulation of a rotating station.
- **Cons**: Directly conflicts with predictable, comfortable movement — walking
  becomes asymmetric depending on direction of travel, which players would read
  as an unintentional bug, not a feature, in a non-spaceflight game.
- **Rejection Reason**: Explicitly rejected in the GDD (see Edge Cases in
  `design/gdd/000-igrovoe-okruzhenie.md`) — parasitic complexity, no gameplay payoff.

### Alternative 3 (2026-07-28 revision): Continuous frame-blend crossing instead of a discrete lock chamber
- **Description**: Let the player walk continuously through the arm↔hub
  boundary while their basis smoothly re-orthonormalizes against a
  continuously-varying local "up," with no door/lock, no suppressed input, no
  discrete cycle — the transition would be as free as walking anywhere else in
  the rotating assembly.
- **Pros**: No forced-wait UX beat; reads as more seamless/immersive.
- **Cons**: Requires the physics/floor-contact resolution to remain stable
  while the effective "up" direction and floor angular velocity are both
  changing under the player's feet in real time — precisely the failure mode
  Alternative 1 (above) already demonstrated as unstable for the *constant-ω*
  case; doing it with **time-varying** ω is strictly harder, not easier.
- **Rejection Reason**: The user explicitly asked for a "more realistic"
  transition but the discrete lock-chamber cycle (suppressed input, scripted
  ω(t) ramp, door-locked-until-synced) already delivers the realism (a real
  mechanical spin-sync event, not a teleport) without reopening the exact
  physics-stability problem this ADR exists to avoid.

## Consequences

### Positive
- Physics is stable enough to ship (for the original torus geometry): player
  can walk a full lap, jump, and stand still without fighting the rotating
  parent.
- Single shared "up"/gravity contract (ADR-0001) means every future system
  placed anywhere in the rotating assembly gets correct orientation for free —
  this held for the torus and continues to hold for the dumbbell (the formula
  was already general over any radius, see GDD 000's `[ring-artificial-gravity]`
  Output Range note added in the 2026-07-28 revision).
- **(New, 2026-07-28)** The lock-chamber re-parent pattern reuses an
  already-shipped primitive (GDD 100's `teleport_to_module()` discrete
  re-parenting), rather than inventing a new player-transfer mechanism from
  scratch.

### Negative
- **Known, documented residual drift** (not fixed, accepted as-is at ship time
  **for the old torus geometry**): tangential drift up to 0.87 m over 10s
  standing still (tolerance was <0.01 m), and up to ~4.8-4.9° azimuth
  divergence over a full lap (tolerance ±0.5°). Root cause: Jolt's contact
  resolution against the rotating floor reintroduces noise that the analytical
  radius-snap (implemented as a mitigation) does not fully cancel tangentially.
  See `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md` Acceptance Criteria
  for the full list of affected tests (T-24, T-25, T-28). **This has not been
  re-measured against the new dumbbell floor geometry** — station geometry
  hasn't been re-implemented yet (see GDD 000's Acceptance Criteria closing
  note); treat as an open risk, not a resolved one, once implementation starts.
- A fallback mitigation ("explicitly multiply velocity by the parent's basis
  delta each frame") was identified but not implemented — left as a documented
  option for a future pass if the drift proves player-visible in actual play.
- **(New, 2026-07-28)** The lock-chamber cycle (5-12s, input suppressed) is a
  forced-wait UX beat at every module transit that did not exist in the torus
  design — a real pacing cost, deliberately accepted as the price of a "more
  realistic" frame crossing (user's explicit call over `/design-system`).

### Risks
- **R-03/R-04 (ТЗ-000/ТЗ-100)**: procedural floor geometry (16 chord segments
  per arc, **torus-specific — the dumbbell's arm/module floors have not been
  re-specified at this level of detail yet**) may contribute micro-steps at
  seams, compounding the drift above. Mitigation path (smoothing collision
  normals) is documented but not applied.
- **(New, 2026-07-28)** Re-parenting the player across three different nodes
  (`RotatingAssembly` ↔ `LockChamber` ↔ `DespunHub`) at each door threshold
  must preserve global transform continuity exactly — any discontinuity reads
  as a visible teleport pop, the opposite of the "more realistic" transition
  this revision exists to deliver. Not yet implemented or tested.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md | Player must be a child of the rotating parent; velocity math in its local space (Core Rule 1) | Defines exactly this parent-child + local-velocity architecture, now onto `RotatingAssembly` instead of the old `RotatingRing` |
| design/gdd/000-igrovoe-okruzhenie.md | Gravity/up contract must be the single source of truth for all consumers (Core Rule 6, renumbered from Rule 5 in the 2026-07-28 revision) | Player controller consumes `get_gravity_up_at()`/`get_gravity_at()` directly, never reimplements |
| design/gdd/000-igrovoe-okruzhenie.md | **(New)** Central hub is despun; torus-era hub+spokes co-rotation is gone (Core Rule 4) | `DespunHub` decision above |
| design/gdd/000-igrovoe-okruzhenie.md | **(New)** Lock-chamber frame crossing at each arm↔hub junction (Core Rule 5, `[lock-chamber-spin-sync]`) | `LockChamber` node + re-parent-at-threshold decision above |

## Performance Implications
- **CPU**: Negligible extra cost — one basis reorthonormalization per physics
  frame, no different in cost from a naive global-space approach.
  **(New, 2026-07-28)** The lock chamber's `ω(t)` is a closed-form function of
  elapsed cycle time (see `[lock-chamber-spin-sync]`, GDD 000) — no per-frame
  integration needed, negligible added cost, only active during the ≤2 cycles
  per module transit.
- **Memory**: None.
- **Load Time**: None.
- **Network**: N/A.

## Migration Plan
**(Added 2026-07-28)** This ADR now describes the *target* architecture for a
station geometry that has not been re-implemented yet — `src/environment/
station/` (story `production/epics/000-igrovoe-okruzhenie/
003-station-orbit-and-ring.md`) still builds the old torus. Migration path,
when that story is re-run: replace the single co-rotating `RotatingRing` (hub +
spokes + ring) with three nodes (`RotatingAssembly`, `DespunHub`,
`LockChamber` ×2); re-parent logic for `Door`/`WorkPanel`/player must move from
"child of RotatingRing always" to "child of whichever of the three nodes the
object currently occupies." No prior-to-torus architecture existed, so this is
the project's first real ADR migration, not a from-scratch decision.

## Validation Criteria
- AC-01 (ТЗ-100): parent of `Player` node is the rotating parent (renamed from
  `RotatingRing`, exact name TBD at implementation); `local_velocity` does not
  rotate with it.
- AC-06/AC-07: full-lap walk test and 5-minute standing-still drift test — see
  Acceptance Criteria in `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md` for
  current (non-passing, documented) status on the tangential drift tests.
  **These are stale in the same way described throughout this revision** (no
  more closed "lap," GDD 100 itself hasn't been propagated yet — run
  `/propagate-design-change design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`
  once that GDD is updated) — do not treat as currently passing criteria for
  the new geometry.
- **(New, 2026-07-28)** See `design/gdd/000-igrovoe-okruzhenie.md` Acceptance
  Criteria for the full new criteria set: lock-chamber ω(t)/g(t) monotonicity
  (both directions), door-lock-until-synced, movement suppression during the
  cycle, hub-despun measurement, and the continuous gravity gradient along
  the arm.

## Related Decisions
- ADR-0001 (two-layer spatial model + coordinate convention)
- `design/gdd/000-igrovoe-okruzhenie.md`, `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`
