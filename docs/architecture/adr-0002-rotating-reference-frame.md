# ADR-0002: Rotating Reference Frame — Player as Child of RotatingRing, No Coriolis Simulation

## Status
Accepted

## Date
2026-07-27 (decided in ТЗ-000 v0.3 / ТЗ-100 v0.3; retrofitted into ADR format
2026-07-28 during gamedev plugin adoption — no new decision)

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
- Must support walking a full lap (376.99 m) without falling through geometry.

## Decision

The player (`CharacterBody3D`) is a **child node of `RotatingRing`**, and all
velocity math is carried out in the ring's own local coordinate system — which is
treated as inertial for the purposes of the player controller. Velocity is
converted to global space exactly once per physics frame, immediately around the
`move_and_slide()` call. Every frame, the player's basis is re-orthonormalized
against the current "up" direction (from `StationRoot.get_gravity_up_at()`),
while preserving the previous frame's look direction — see the
`ring-up-direction` and `player-basis-reorientation` formulas in
`design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`.

**Coriolis force is explicitly not modeled** (inherited from ADR-0001's parent
assumption in ТЗ-000 A-03): the physically correct effect (30.1% of g at walking
speed, 54.2% at running speed) would make clockwise vs. counter-clockwise travel
around the ring feel meaningfully different, which is parasitic complexity for a
signal-relay operator game, not a spaceflight-realism game.

### Architecture Diagram
```
RotatingRing (rotates continuously, angle = f(epoch_days))
  └─ Player (CharacterBody3D)
       local_velocity: Vector3   ← source of truth, ring-local space
       (converted to global once per physics frame, around move_and_slide())
  └─ [future] Door, WorkPanel, other ring-mounted objects
```

### Key Interfaces
- `PlayerController.local_velocity: Vector3` (ring-local, source of truth)
- `StationRoot.get_gravity_up_at(p: Vector3) -> Vector3` (consumed, not reimplemented)
- `StationRoot.get_gravity_at(p: Vector3) -> Vector3` (consumed, not reimplemented)

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

## Consequences

### Positive
- Physics is stable enough to ship: player can walk a full lap, jump, and stand
  still without fighting the rotating parent.
- Single shared "up"/gravity contract (ADR-0001) means every future system placed
  in the ring gets correct orientation for free.

### Negative
- **Known, documented residual drift** (not fixed, accepted as-is at ship time):
  tangential drift up to 0.87 m over 10s standing still (tolerance was <0.01 m),
  and up to ~4.8-4.9° azimuth divergence over a full lap (tolerance ±0.5°). Root
  cause: Jolt's contact resolution against the rotating floor reintroduces noise
  that the analytical radius-snap (implemented as a mitigation) does not fully
  cancel tangentially. See `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`
  Acceptance Criteria for the full list of affected tests (T-24, T-25, T-28).
- A fallback mitigation ("explicitly multiply velocity by the parent's basis
  delta each frame") was identified but not implemented — left as a documented
  option for a future pass if the drift proves player-visible in actual play.

### Risks
- **R-03/R-04 (ТЗ-000/ТЗ-100)**: procedural floor geometry (16 chord segments per
  arc) may contribute micro-steps at seams, compounding the drift above.
  Mitigation path (smoothing collision normals) is documented but not applied.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md | Player must be a child of the rotating ring; velocity math in ring-local space (Core Rule 1) | Defines exactly this parent-child + local-velocity architecture |
| design/gdd/000-igrovoe-okruzhenie.md | Gravity/up contract must be the single source of truth for all consumers (Core Rule 5) | Player controller consumes `get_gravity_up_at()`/`get_gravity_at()` directly, never reimplements |

## Performance Implications
- **CPU**: Negligible extra cost — one basis reorthonormalization per physics
  frame, no different in cost from a naive global-space approach.
- **Memory**: None.
- **Load Time**: None.
- **Network**: N/A.

## Migration Plan
N/A — original decision, no prior architecture.

## Validation Criteria
- AC-01 (ТЗ-100): parent of `Player` node is `RotatingRing`; `local_velocity` does
  not rotate with the ring.
- AC-06/AC-07: full-lap walk test and 5-minute standing-still drift test — see
  Acceptance Criteria in `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md` for
  current (non-passing, documented) status on the tangential drift tests.

## Related Decisions
- ADR-0001 (two-layer spatial model + coordinate convention)
- `design/gdd/000-igrovoe-okruzhenie.md`, `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md`
