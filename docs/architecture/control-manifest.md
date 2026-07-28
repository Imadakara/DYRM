# Control Manifest

> **Engine**: Godot 4.7 (GDScript)
> **Last Updated**: 2026-07-28
> **Manifest Version**: 2026-07-28
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed this
date when created. `/story-readiness` compares a story's embedded version to this
field to detect stories written against stale rules.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
`technical-preferences.md`, and CLAUDE.md. For the reasoning behind each rule, see
the referenced ADR.

---

## Foundation Layer Rules

*Applies to: игровое окружение (000), spatial/coordinate math, gravity contract, save/load (073)*

### Required Patterns
- **Two-layer world (Local 1:1m / Deep compressed, SubViewport composited behind)** — source: ADR-0001
- **Ecliptic→Godot conversion only in `SpaceScale.ecliptic_to_godot()`** — source: ADR-0001
- **`StationRoot.get_gravity_up_at()`/`get_gravity_at()` as the sole gravity/up source** — source: ADR-0001, ADR-0002
- **Player parented under `RotatingRing`; velocity math in ring-local space** — source: ADR-0002

### Forbidden Approaches
- **Never** reimplement the ecliptic→Godot conversion outside `SpaceScale` — source: ADR-0001
- **Never** give a system its own gravity/up computation — source: ADR-0001, ADR-0002
- **Never** simulate the Coriolis force — source: ADR-0002
- **Never** add an autoload without an ADR justifying it — source: ADR-0004

### Performance Guardrails
- **Deep-layer rendering**: keep near-static; half-resolution + upscale if iGPU overhead appears — source: ADR-0001
- **Whole scene**: ≤200,000 triangles, ≤50MB assets (ТЗ-000 NFR-09)

---

## Core Layer Rules

*Applies to: player controller, interaction contract, work panels, laser/antenna/panel equipment systems (013–039)*

### Required Patterns
- **`Interactable` base contract** (`can_interact()`, `interact()`) for every interactive object — source: `design/gdd/100-...md`
- **`WorkPanel` renders UI via `SubViewport` onto a flat mesh; content attached via `set_ui_scene()`/`get_ui_root()` without editing `WorkPanel` itself** — source: ADR-0004 (pattern), `design/gdd/100-...md`
- **Cross-node references via `@export NodePath` / `@onready` / groups**, never a fixed autoload list or fixed `SceneTree` root indices — source: ADR-0004
- **Every debug-bound input has a public programmatic twin method** — source: ADR-0004 (tooling rationale), `design/gdd/100-...md`

### Forbidden Approaches
- **Never** assume a fixed, closed set of autoloads — the MCP live bridge injects one at runtime — source: ADR-0004
- **Never** give `WorkPanel` type-specific logic for its content (`InteractionProbe` must stay content-agnostic) — source: `design/gdd/100-...md`

### Performance Guardrails
- **Panel repaint**: invisible/static `SubViewport`s must not redraw; total panel repaint cost ≤2ms/frame (ТЗ-100 NFR-02)
- **Frame rate**: ≥60 FPS at 1920×1080 with all 7 rubka panels visible

---

## Feature Layer Rules

*Applies to: signal processing loop (021–029), timers/queue/errors/scoring (041–058), equipment state (031–310)*

### Required Patterns
- **No numeric literals in scripts** except universal constants (`KM_PER_AU`, `G`, `TAU`) — all tunable parameters live in typed `.tres` resources — source: CLAUDE.md, ADR-0003
- **Flat, typed `@export` config** — `Resource`-in-`Resource` nesting no deeper than one level — source: CLAUDE.md

### Forbidden Approaches
- **Never** hardcode a numeric gameplay constant directly in a `.gd` file — source: CLAUDE.md
- **Never** use API newer than Godot 4.2 stability floor without flagging it first — source: ADR-0003

---

## Presentation Layer Rules

*Applies to: звёздная карта (025), UI content inside panels, debug overlay, future audio (015)*

### Required Patterns
- **Diagnostics mirrored into the live scene tree** (named `Control`/`Label` nodes), not `print()`-only — source: CLAUDE.md "Debugging conventions"
- **Named, deterministic camera angles** switchable in code for visual verification — source: ADR-0004 (tooling rationale)

### Forbidden Approaches
- **Never** ship a diagnostic that only works via `_draw()` or floating 3D text — must be auto-checkable via a `Control` node — source: CLAUDE.md

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController` |
| Variables/functions | snake_case | `move_speed` |
| Signals | snake_case, past tense | `health_changed` |
| Files | snake_case matching class | `player_controller.gd` |
| Scenes | PascalCase matching root node | `PlayerController.tscn` |
| Constants | UPPER_SNAKE_CASE | `KM_PER_AU` |
| Comments (formulas/constants) | Russian | `# сжатое расстояние, формула 6.4.3` |

### Performance Budgets
| Target | Value |
|--------|-------|
| Framerate | 60 FPS |
| Frame budget | 16.6 ms |
| Triangle budget | ≤200,000 / scene |
| Asset budget | ≤50 MB / scene |

### Approved Libraries / Addons
- None — stock Godot 4.7 only (Jolt Physics is a built-in backend, not a third-party addon)

### Forbidden APIs (Godot 4.7)
- No specific deprecated-API list maintained — project instead holds a blanket
  floor at "only API stable since 4.2" (see ADR-0003). If a genuine 4.3-4.7 API
  gap is hit during implementation, run `/setup-engine refresh` before using it.

### Cross-Cutting Constraints
- Every script parses independently — no cyclic `preload`, no parse-time
  dependency on an autoload (ADR-0004).
- No allocations in hot `_process` loops.
- Project must open in the editor with zero errors/warnings in the console.
- Static typing mandatory for every variable, parameter, and return value;
  `Variant` only where the type is genuinely unknown.
- Every script declares `class_name`.
