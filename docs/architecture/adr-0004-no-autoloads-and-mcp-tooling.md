# ADR-0004: No Autoloads Without Justification + Godot MCP as the Standard Tooling Bridge

## Status
Accepted

## Date
2026-07-25 (decided at project start; formalized in ТЗ-000 §7.7; retrofitted into
ADR format 2026-07-28 during gamedev plugin adoption)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 |
| **Domain** | Core |
| **Knowledge Risk** | LOW — Autoload/singleton mechanics and MCP-style external TCP bridges use only long-stable Godot APIs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (engine/tech stack pin) |
| **Enables** | Consistent node-reference patterns for every future system |
| **Blocks** | None |
| **Ordering Note** | None |

## Context

### Problem Statement
Two related tooling/architecture problems needed a standing policy: (1) how
cross-node references should work without accumulating implicit global state, and
(2) how development/verification tooling (headless scene editing, live runtime
inspection) integrates with the project without polluting the shipped game.

### Constraints
- GDScript-only, no addons (ADR-0003).
- The project is developed via Claude Code using MCP servers that manipulate the
  live Godot project — this tooling must never leave a trace in the shipped
  repository.
- Debug/verification tooling must work in both headless (backgrounded, no
  physical input) and interactive modes.

### Requirements
- Cross-system references must be resolvable without hardcoding a global
  autoload list that every system implicitly depends on.
- Every script must parse independently — no cyclic `preload`, no parse-time
  dependency on an autoload.
- Development tooling must support headless scene/node/script editing plus a live
  runtime bridge (screenshots, input simulation, scene-tree inspection, GDScript
  execution) without becoming part of the shipping game.

## Decision

**No autoloads without explicit justification recorded in an ADR** (superseding
the pre-adoption phrasing "justification in a ТЗ" — same rule, new home for the
justification). Cross-node references go through `@export var ... : NodePath` or
`@onready`, resolved by name, group, or exported path — never by assuming a fixed
autoload list or fixed `SceneTree` root child indices.

Rationale tied directly to tooling: the project's MCP-based development tooling
(`godot-runtime` primary, `godot` secondary) **injects a temporary autoload** —
a localhost TCP listener bridge — into the running project on launch, and removes
it on stop. Any script or system that assumes a fixed, closed set of autoloads
would break the moment this injected bridge is present. The "no fixed autoload
list" rule is therefore not just a style preference — it is what keeps the live
MCP bridge from corrupting gameplay logic that inspects the autoload list or
`SceneTree` structure.

This same tooling constraint is why two other project-wide conventions exist:
- **Programmatic twins for every debug key binding** — physical input is blocked
  when the project runs headless/backgrounded under MCP.
- **Named, deterministic camera angles** switchable in code — visual verification
  through the MCP bridge needs a repeatable way to reach a specific view without
  physical camera control.

### Architecture Diagram
```
Development session (Claude Code)
  ├─ godot-runtime MCP (primary): headless scene/node/script/signal/autoload edits,
  │    project search, pre-launch validation, live bridge (screenshots, input sim,
  │    scene-tree traversal, GDScript execution) — bridge = temporary injected autoload
  └─ godot MCP (secondary): editor/project launch, output reading, UID management

Shipped project: zero trace of either MCP or the injected bridge autoload.
```

### Key Interfaces
- No new public API — this ADR is a *pattern* constraint (no autoloads, use
  `NodePath`/`@onready`/groups), not a code contract.

## Alternatives Considered

### Alternative 1: Standard autoload-heavy architecture (event bus, global GameState singleton, etc.)
- **Description**: Use Godot's common autoload pattern for cross-system
  communication (a global `EventBus`, `GameState`, etc.), as the wider
  `gd-agentic-skills` library's `godot-autoload-architecture` skill recommends
  by default.
- **Pros**: Familiar, well-documented Godot pattern; less boilerplate for
  cross-system signals.
- **Cons**: Directly conflicts with the MCP live-bridge injection (a fixed
  autoload list becomes an incorrect assumption baked into gameplay code the
  moment the bridge is present); increases implicit global coupling as the
  system count grows toward 53.
- **Rejection Reason**: The tooling constraint is not negotiable for this
  project — verification depends on the injected bridge working reliably every
  session.

### Alternative 2: Dependency-injection container / service locator
- **Description**: A more structured DI framework instead of ad hoc
  `NodePath`/group lookups.
- **Pros**: More explicit dependency graph.
- **Cons**: No mature, idiomatic GDScript-only pattern for this without a custom
  framework layer — adds complexity disproportionate to a ~53-system, single-
  developer project.
- **Rejection Reason**: `@export NodePath`/`@onready`/groups already solve the
  problem at the project's actual scale.

## Consequences

### Positive
- The MCP live bridge can be injected/removed every session without any gameplay
  script needing to special-case its presence.
- Every script parses independently — no hidden load-order dependency chains.

### Negative
- Slightly more verbose cross-node wiring (`@export NodePath` fields to set up
  per-scene) compared to a global singleton lookup.
- Any future system that genuinely needs global, session-wide state (e.g. a save
  system, 073) must justify its autoload explicitly in its own ADR rather than
  defaulting to one.

### Risks
- **Contributors reaching for the wider `gd-agentic-skills` library's
  `godot-autoload-architecture` patterns by default** — mitigated by this ADR
  being the explicit, project-specific override (see CLAUDE.md "External Godot
  skill library" section).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| design/gdd/000-igrovoe-okruzhenie.md | Debug tooling requirements (named camera presets, programmatic debug twins) | Explains the tooling constraint (MCP live bridge) that these requirements exist to serve |
| design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md | FR-50 (every debug key binding needs a programmatic twin) | Same tooling rationale |

## Performance Implications
- **CPU/Memory**: Negligible — `NodePath` resolution is a one-time `@onready` cost.
- **Load Time**: None.
- **Network**: The MCP bridge itself is a localhost TCP listener, active only
  during development sessions — no implication for the shipped game.

## Migration Plan
N/A — original decision, no prior architecture.

## Validation Criteria
- No project script assumes a fixed autoload list or fixed root `SceneTree`
  child indices — checked ad hoc during code review, not currently automated.
- Project opens and runs cleanly both with and without the MCP bridge attached.

## Related Decisions
- ADR-0003 (engine/tech stack pin)
- CLAUDE.md "Tooling (Godot MCP)" and "Code conventions" sections
