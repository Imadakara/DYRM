# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

DYRM (*Do You Read Me?*) — a first-person simulator/puzzle game about operating a laser-relay
communication station in orbit around Neptune (year 2426). The player decodes message addresses
(`Sector: H-17 / Cluster: Orion / Relay: 8 / Mirror: C`), locates the target on in-game star charts,
and aims a laser to relay the message — under increasing equipment failures, encryption, queues and
time pressure. Genre: Simulation · Puzzle · Time Management · Sci-Fi · First Person.

**Current state: two MVP systems shipped** — 000 (Игровое окружение) and 100 (Игрок и станция от
первого лица), see git commits "System 0 mvp done" / "System 1 mvp done". `scenes/`, `src/`,
`resources/`, `materials/`, `tools/` are populated; 51 of 53 planned systems remain not started (see
`design/gdd/systems-index.md`).

## Development pipeline (gamedev plugin)

As of 2026-07-28 the project fully adopted the `gamedev` Claude Code plugin as its development
pipeline, replacing the prior two-repository ГДД→ТЗ process below. Design docs, architecture
decisions, and production tracking now live **inside this repo**, in the layout the plugin's skills
expect:

- `design/gdd/game-concept.md`, `design/gdd/systems-index.md` — concept and systems registry.
- `design/gdd/NNN-kebab-case-name.md` — one GDD per system, **`NNN` keeps the pre-existing ТЗ
  numbering convention** (GDD dotted number with the dot removed: `0.1`→`001`, `2.7`→`027`, a whole
  block→`000`) for continuity with code comments (`# FR-12`, `TODO(ТЗ-027)`) and cross-references
  already embedded in the two shipped systems. See the naming-convention note at the top of
  `design/gdd/systems-index.md` before running `/design-system` or `/map-systems`.
- `docs/architecture/adr-NNNN-slug.md` — Architecture Decision Records (`/architecture-decision`).
- `docs/architecture/tr-registry.yaml`, `docs/registry/architecture.yaml` — stable requirement IDs
  and locked architectural stances (`/architecture-review`).
- `docs/architecture/control-manifest.md` — the flat, per-layer rules sheet for programmers
  (`/create-control-manifest`).
- `production/epics/`, `production/sprint-status.yaml`, `production/stage.txt`,
  `production/review-mode.txt` (set to `lean`) — production tracking.

Workflow going forward: **`/map-systems` → `/design-system` (GDD) → `/architecture-decision` (ADR)
→ `/create-epics` → `/create-stories` → `/dev-story` → `/story-done`**, gated by `/gate-check`
between phases. See `docs/adoption-plan-2026-07-28.md` for the full migration record, including how
the two already-shipped systems were backfilled into this format.

**Legacy (historical reference only, not part of the active workflow):** the prior process —
sibling repo `DYRM Docs` (concept doc, `ГДД - Перечень систем.md`, `ТЗ/ТЗ-NNN — Название.md` specs)
plus the project-scoped `dyrm-tz` skill (`.claude/skills/dyrm-tz/`) — produced the original design
for systems 000 and 100 and is preserved there unmodified. `design/gdd/000-*.md` and
`design/gdd/100-*.md` are direct ports of `ТЗ-000`/`ТЗ-100` (no new decisions made in the port); the
original ТЗ documents remain the more detailed historical implementation record, cited from the new
GDDs. Do not write new ТЗ documents or invoke `dyrm-tz` for new work — use the gamedev plugin skills
above instead.

## Tech stack and constraints

| | |
|---|---|
| Engine | Godot 4.7, Forward+ renderer |
| Language | GDScript only — no C#, no GDExtension, no third-party addons |
| Physics | Jolt Physics |
| Graphics driver | D3D12 on Windows |
| Target | Desktop, 1920×1080, ≥60 FPS on a laptop iGPU |
| API compatibility | Use only API stable since **Godot 4.2**, even though the project builds on 4.7 |

## Code conventions (apply project-wide)

- Static typing is mandatory for every variable, parameter and return value. `Variant` only where
  the type is genuinely unknown.
- Every script declares `class_name`.
- Identifiers in English: `snake_case` for functions/variables, `PascalCase` for classes/nodes.
  Comments explaining formulas and physical constants are written **in Russian**.
- Reference requirement IDs in comments where useful (`# FR-12`); mark deferred work as
  `TODO(ТЗ-027)`, naming the owning spec.
- **No numeric literals in scripts** except universal constants (`KM_PER_AU`, `G`, `TAU`). All
  tunable parameters live in `.tres` resources.
- Config is **flat, typed `@export`** — `Resource`-in-`Resource` nesting no deeper than one level.
- Inspectable state is exposed via getters and public properties, never derived from private state
  by callers.
- **No autoloads** without explicit justification in an ADR (see `docs/architecture/adr-0004-*.md`).
  Cross-node references go through
  `@export var ... : NodePath` or `@onready`.
- Don't rely on a fixed autoload list or on root `SceneTree` child indices — the MCP tooling injects
  a temporary autoload into the running project. Reference nodes by name, group, or exported path.
- Every script must parse independently: no cyclic `preload`, no parse-time dependency on an
  autoload.
- No allocations in hot `_process` loops.
- The project must open in the editor with **zero errors or warnings** in the console.

### Debugging conventions

- Every debug key binding needs a **programmatic twin** (a public method or Godot action) — physical
  input is blocked when the project runs headless/backgrounded.
- Visual checks are tied to **named, deterministic camera angles** switchable in code.
- Diagnostics aren't `print()`-only; important state is mirrored into the live scene tree.
- Auto-checkable diagnostics render to `Control` nodes, not just `_draw()` or 3D text.

## Coordinates and units (fixed by ТЗ-000, applies to every spatial system)

| Quantity | Unit |
|---|---|
| Scene length | 1 meter = 1 Godot unit |
| Data length | kilometer |
| Planetary semi-major axes | AU, `KM_PER_AU = 149 597 870.7` |
| Time | days since J2000.0 epoch (`epoch_days`) |
| Angles in data | degrees (converted to radians immediately in code) |
| Angles in API | radians, except azimuth/elevation |

Godot uses a right-handed system, **+Y up**, **−Z forward**. The J2000 ecliptic plane maps to the
**XZ** plane via `godot_vec = Vector3(ecl.x, ecl.z, -ecl.y)`. This conversion exists in **exactly
one place**, `OrbitalMath.ecliptic_to_godot()` — never duplicate it (see ADR-0001).

Aiming basis `Station/AimingReference` (fixed to the station truss): **+Y** = local zenith (Neptune
center → station), **−Z** = orbital velocity vector, **+X** completes the right-handed triad.
**Azimuth**: in the XZ plane, clockwise from −Z viewed from +Y, range [0°, 360°). **Elevation**:
angle above the XZ plane, range [−90°, +90°]. These conversions must be geometrically exact — a
catalog entry like "Uranus, azimuth 143°" must have the beam actually point at the rendered Uranus.

## Tooling (Godot MCP)

Development uses two MCP servers; default to the runtime one, fall back to the second for
UID operations or as a backup launch path:

- `godot-runtime` (primary): headless scene/node/script/signal/autoload editing, project search,
  pre-launch validation, plus a live bridge into the running project (screenshots, input
  simulation, scene-tree traversal, GDScript execution in the `SceneTree`).
- `godot` (secondary): editor/project launch, output reading, UID management (Godot 4.4+).

The live bridge is a temporary autoload with a localhost TCP listener, injected on launch and
removed on stop — it leaves no trace in the repo. It only works against a running project, so the
project must be launched after each work stage to verify it. In background mode the window is
moved off-screen and physical input is blocked; output reading isn't available when attaching to an
externally-launched process. These constraints are why the "no fixed autoload list", "programmatic
debug twins", and "named deterministic camera angles" rules above exist.

Practical gotchas for these two MCPs (process lifecycle, scene-authoring pitfalls, runtime-tool
quirks) — not just for verification, for everyday scene/node work through them too — live in the
global `godot-mcp-testing` skill (now grouped in the `godot` plugin —
`~/.claude/skills/godot/skills/godot-mcp-testing/`, invoked as `godot:godot-mcp-testing`; see Tests
section below);
check it before improvising a workaround for odd MCP behavior. It's global (not DYRM-specific)
since the same two MCPs and their quirks apply to any Godot project on this machine — DYRM's own
test cases now live as Acceptance Criteria in each story/GDD (see Tests below), not in a separate
local catalog.

## Godot knowledge base (cross-project)

Non-obvious Godot engine/GDScript/MCP behavior that required real diagnosis (not "read the docs and
it worked") is recorded outside this repo, in a knowledge base shared across every Godot project on
this machine — not DYRM-specific:

```
C:\Users\PC\Documents\Development\Claude Common\Knowledge base\Godot\godot-development-knowledge-base.md
```

Before re-diagnosing weird engine/MCP behavior from scratch, check whether it's already recorded
there. Populate it via the global `godot-knowledge-base` skill (also in the `godot` plugin now —
`~/.claude/skills/godot/skills/godot-knowledge-base/`)
after finishing and verifying a ТЗ/task, if something non-trivial came up — both the file and the
skill live outside this repo on purpose, since the same findings apply to any Godot project, not
just DYRM.

## External Godot skill library (gd-agentic-skills)

`~/.claude/skills/godot/skills/` also hosts 97 global skills from `thedivergentai/gd-agentic-skills`
(`godot-master` plus domain/genre skills covering GDScript patterns, architecture, 2D/3D systems,
UI, and per-genre blueprints). These are freely available to consult and draw patterns from for
DYRM work, same as any other Godot project — no blanket restriction against using them. They now
live grouped with `godot-mcp-testing`/`godot-knowledge-base` in one `godot` plugin purely for
command namespacing (`/godot:godot-gdscript-mastery` etc.) — not because they're the same product;
see the global `~/.claude/CLAUDE.md` for the distinction.

That said, this file's own sections above (**Tech stack and constraints**, **Code conventions**,
**Coordinates and units**, **Tooling**) are DYRM's deliberate, ADR-derived source of truth (see
`docs/architecture/adr-0003-*.md`, `adr-0004-*.md`) and win whenever a pattern from that library
would conflict with them — e.g. its `godot-autoload-architecture` skill's autoload-forward patterns
don't override "no autoloads without explicit justification in an ADR" above; its `godot-builder`
skill's own Python/CLI scripts
for driving Godot headlessly are not this project's workflow — use the `godot-runtime`/`godot` MCP
pair via the (separately global) `godot-mcp-testing` skill instead. Most of the library's genre
blueprints and platform-adaptation skills (mobile/console/VR/web ports, multiplayer, most
`godot-genre-*`) are simply not applicable to a singleplayer, desktop-only, first-person
sim/puzzle game — skip them rather than forcing fit.

## Tests

ТЗ-000 defines the autotest entry point (not yet present in the repo):

```bash
godot --headless --path . --script res://tools/run_tests.gd
```

Expected output: one line per test, ending in `RESULT: <N> passed, 0 failed`, exit code 0.

**All testing during development beyond this headless numeric run goes through the global
`godot-mcp-testing` skill** (`~/.claude/skills/godot/skills/godot-mcp-testing/` — not DYRM-specific,
same as any Godot project using this MCP pair): general MCP process/lifecycle discipline, the full
tool catalog for both MCPs, scene-authoring/runtime tool gotchas, the calibration-scene recipe,
screenshots, live-bridge-vs-autotests. Don't improvise MCP verification steps ad hoc.

Per-system test cases now live as **Acceptance Criteria inside each story file**
(`production/epics/*/NNN-*.md`) and each GDD (`design/gdd/*.md`), following the gamedev plugin's own
`/qa-plan` and `/dev-story` conventions — not in a separate catalog. The legacy `dyrm-tz` skill's
test-case catalogs (`references/tz-NNN-test-cases.md` for systems 000/100) remain in
`.claude/skills/dyrm-tz/` as historical reference for those two systems' original verification
sessions; don't extend them for new systems.

## Known documentation discrepancies

Flagged during ТЗ-000 authoring, pending owner decision — don't be surprised by these when they
surface during implementation (see README.md section 10 for full detail):

- System 1.5 (audio) is tagged `[Ext]` in GDD body text but `Core` in the summary table — treat as
  `Core`.
- Block 0 is missing from the GDD priority summary table even though both its systems are `[MVP]`.
- The crew module sits on a rotating ring (~28s sky rotation period) — open question Q-02 in
  ТЗ-000.
- In-universe date is 2426; orbital mechanics is computed from J2000 — keep them decoupled (Q-01 in
  ТЗ-000).
- GDD/ТЗ-000 say "Godot 4.4+"; the project is actually on 4.7 — resolved by the "API stable since
  4.2" constraint above.
