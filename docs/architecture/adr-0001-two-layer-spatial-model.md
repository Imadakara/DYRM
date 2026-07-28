# ADR-0001: Two-Layer Spatial Model (Local/Deep) with Logarithmic Distance Compression

## Status
Accepted

## Date
2026-07-26 (decided in ТЗ-000 v0.3; retrofitted into ADR format 2026-07-28 during
gamedev plugin adoption — no new decision, formalizing what already shipped)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (Forward+ renderer) |
| **Domain** | Rendering / Core |
| **Knowledge Risk** | LOW — `SubViewport`, `World3D`, camera copy-rotation are all API stable since 4.2 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (project's own 4.2-floor mitigation) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None beyond what ТЗ-000's own automated/visual test suite already covers (AC-01…AC-07) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — first ADR |
| **Enables** | ADR-0002 (rotating reference frame; consumes the Local-layer coordinate convention this ADR fixes) |
| **Blocks** | Epic 025 (Звёздная карта), Epic 027 (Наведение лазера) — both require exact direction preservation across layers |
| **Ordering Note** | None |

## Context

### Problem Statement
The game world spans from a station-scale interior (metres) to a solar-system scale
(billions of km). Godot's default `float32` transforms lose usable precision far
below the distances the game needs (Sun at 30 AU ≈ 4.5×10⁹ km), yet the core
gameplay fantasy requires that a direction taken from an in-game catalog ("Uranus,
azimuth 143°") point at the *actual* rendered planet — not a decorative backdrop.

### Constraints
- Godot builds used by the project are single-precision (`float32`) — no
  double-precision build.
- Target hardware is a laptop-class iGPU — cannot afford a second full-detail
  world.
- Direction accuracy must hold to ≤0.05° (NFR-03, ТЗ-000).
- No numeric literals allowed in scripts — all scale constants live in `.tres`.

### Requirements
- Must render station interior (radius ≤2000 m) at 1:1 scale for gameplay
  precision (physics, collision, laser aiming geometry).
- Must render the rest of the solar system without float precision breakdown.
- Must preserve exact direction to every celestial body regardless of which layer
  renders it.
- Must keep angular size accurate down to a visibility floor, below which further
  shrinking would make a body disappear into a subpixel.

## Decision

Split the world into two layers:

- **Local** (radius 2000 m, 1:1 metre = 1 Godot unit): contains the station and
  everything gameplay-relevant (physics, collision, the player).
- **Deep**: contains everything else (planets, Sun, star field, Kuiper belt),
  rendered in a separate `SubViewport`/`World3D`, composited **behind** Local
  without writing to the main depth buffer. Its camera copies the main camera's
  global **rotation** and FOV every frame, staying at its own world origin — this
  keeps parallax-free "infinite distance" behavior cheaply.

Distance into the Deep layer is logarithmically compressed
(`d_render = K·ln(1 + d_km/D₀)`, `K=220.0` units, `D₀=1.0e6` km) — strictly
monotonic, so depth ordering never inverts. **Direction is never touched**: the
unit direction vector is computed in kilometres before compression, then scaled by
the compressed distance. Angular size is preserved exactly above a
`min_angular_diameter_deg` threshold (0.12°); below it, size is clamped to the
threshold rather than shrinking further.

The ecliptic-to-Godot axis convention is fixed in exactly one place,
`OrbitalMath.ecliptic_to_godot()`: `godot_vec = Vector3(ecl.x, ecl.z, -ecl.y)`
(Godot: +Y up, −Z forward; ecliptic plane maps to Godot's XZ plane). This
conversion must never be duplicated elsewhere in the codebase. (ТЗ-000's spec
text named this `SpaceScale.ecliptic_to_godot()`; the shipped implementation
placed it on `OrbitalMath` instead — a minor naming deviation from the original
spec, corrected here to match the actual code.)

### Architecture Diagram
```
Main Viewport (Local, 1:1 m, physics-authoritative)
  └─ Camera3D (player-controlled)
Deep SubViewport (own World3D, no depth write, composited behind)
  └─ Camera3D (copies main camera rotation+FOV each frame, fixed at own origin)
       └─ Sun, 8 planets, Triton, star field, Kuiper belt (compressed distance)
```

### Key Interfaces
- `SpaceScale.compress_distance(d_km: float) -> float`
- `SpaceScale.render_radius(R_km: float, d_km: float) -> float`
- `OrbitalMath.ecliptic_to_godot(ecl: Vector3) -> Vector3`
- `CelestialBody.direction_from_station() -> Vector3` (unit, exact, computed pre-compression)

## Alternatives Considered

### Alternative 1: Double-precision Godot build
- **Description**: Use a `float64`-patched Godot build to represent true
  kilometre-scale coordinates directly.
- **Pros**: No compression math, no dual-viewport compositing complexity.
- **Cons**: Non-standard engine build, breaks the project's "stock Godot, no
  custom engine build" constraint; still wastes precision on a single world that
  must serve both metre-scale physics and billion-km-scale rendering simultaneously.
- **Rejection Reason**: Out of scope for a GDScript-only, stock-engine project;
  doesn't actually solve the dual-scale precision problem, just delays it.

### Alternative 2: Skybox / static backdrop for distant objects
- **Description**: Render distant planets as a pre-baked skybox texture, not real
  3D objects with true positions.
- **Pros**: Trivial performance cost, no compression math.
- **Cons**: Breaks the core gameplay fantasy directly — a skybox can't be aimed at
  with a real azimuth/elevation computed from live orbital mechanics; direction
  would decouple from the aiming system entirely.
- **Rejection Reason**: Violates the system's own success criterion (ТЗ-000 §1.4).

## Consequences

### Positive
- Aiming and star-map systems can trust one shared geometry source for both
  "what's on screen" and "what direction is that" — no duplicate approximation.
- Physics-critical Local layer never touches large numbers; no z-fighting or
  jitter from float32 precision loss.
- Distant-object rendering cost stays low (few thousand near-static points/meshes).

### Negative
- A second `SubViewport`/`World3D` has real overhead, particularly on integrated
  graphics (see Risks).
- Two coordinate systems in the codebase (Local metres vs. Deep compressed units)
  is an extra concept every new system touching the sky must understand.

### Risks
- **Overhead on weak iGPUs** — mitigated by rendering Deep at half resolution with
  upscale if needed; the Deep layer content is nearly static frame-to-frame.
- **Visible seam or wrong transparency ordering between layers** — mitigated by
  drawing Deep first with no depth write; the station's floor viewport (in the
  Комната связи иллюминатор) is the only transparency crossing the seam and is
  tested separately.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| design/gdd/000-igrovoe-okruzhenie.md | Two spatial layers, monotonic strictly-increasing distance compression preserving exact direction (Core Rule 1, Formulas) | Defines the exact compression formula, the SubViewport compositing approach, and the single-source-of-truth coordinate conversion |

## Performance Implications
- **CPU**: Negligible — compression is a single `ln()` call per visible body per frame.
- **Memory**: Second `World3D` doubles some renderer bookkeeping but content is low-poly/point-based.
- **Load Time**: No impact — no additional asset loading.
- **Network**: N/A (single-player).

## Migration Plan
N/A — this is the original decision for a system built from scratch; no prior
architecture to migrate from.

## Validation Criteria
- AC-04/AC-05 (ТЗ-000): `compress_distance` strictly monotonic across 1e3…1e10 km,
  direction error <0.001° between Local and Deep representations of the same body.
- AC-06: `render_radius` matches reference table within 0.001 units.
- NFR-03: direction error to any body ≤0.05° from station.
- All verified by `tools/run_tests.gd` (headless) at time of ТЗ-000 acceptance —
  see `design/gdd/000-igrovoe-okruzhenie.md` Acceptance Criteria.

## Related Decisions
- ADR-0002 (rotating reference frame) builds directly on the Local-layer
  coordinate convention fixed here.
- `design/gdd/000-igrovoe-okruzhenie.md`, `design/gdd/025-...` (future — звёздная карта)
