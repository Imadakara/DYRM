# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

DYRM (*Do You Read Me?*) — a first-person simulator/puzzle game about operating a laser-relay
communication station in orbit around Neptune (year 2426). The player decodes message addresses
(`Sector: H-17 / Cluster: Orion / Relay: 8 / Mirror: C`), locates the target on in-game star charts,
and aims a laser to relay the message — under increasing equipment failures, encryption, queues and
time pressure. Genre: Simulation · Puzzle · Time Management · Sci-Fi · First Person.

**Current state: no code, scenes or resources exist yet.** Only `project.godot`, `icon.svg`,
`.gitignore`/`.editorconfig`/`.gitattributes` are in place. The first implementation task is ТЗ-000
("Игровое окружение"), which scaffolds `scenes/`, `src/`, `resources/`, `materials/`, `tools/`.

## Two-repository split

Design docs and code live in **separate repositories on purpose** — documentation outlives several
code iterations:

- **`DYRM`** (this repo): code, scenes, resources, tests, Claude Code skills.
- **`DYRM Docs`** (sibling repo, not this one): concept doc, GDD, and per-system technical specs
  (ТЗ). Layout: `Идея игры - DYRM.md` (concept/MVP), `ГДД - Перечень систем.md` (registry of all 53
  systems), `ТЗ/ТЗ-NNN — Название.md` (one spec per system), `ТЗ/_ШАБЛОН ТЗ.md` (template mirror).

Workflow: **ГДД (what the system is) → ТЗ (how to build it) → Claude Code implementation → review
against acceptance criteria.** One GDD system = one ТЗ document = one Claude Code task; never mix
systems in a single task — scope boundaries are the main quality-control lever. Each ТЗ contains a
self-contained, copy-pasteable prompt for Claude Code in its section 13.

ТЗ naming: `ТЗ-NNN — Название.md`, where `NNN` is the GDD system number with the dot removed
(`0.1`→`010`, `2.7`→`027`, a whole block→`000`).

## Writing/updating ТЗ specs

Use the `dyrm-tz` skill (`.claude/skills/dyrm-tz/`) for drafting or revising ТЗ documents — it
encodes the canonical template, the process, and the five most common mistakes (scope creep,
unverifiable requirements, non-self-contained prompts, unsourced numbers, over-specifying tooling).
Validate a spec with:

```bash
python3 .claude/skills/dyrm-tz/scripts/validate_tz.py "путь/к/ТЗ-NNN — Название.md"
```

This checks requirement/acceptance-criteria coverage, ID uniqueness, prompt self-sufficiency, and
file-tree consistency — not semantic correctness (that's the template's section 14 checklist, read
by eye).

## Tech stack and constraints

| | |
|---|---|
| Engine | Godot 4.7, Forward+ renderer |
| Language | GDScript only — no C#, no GDExtension, no third-party addons |
| Physics | Jolt Physics |
| Graphics driver | D3D12 on Windows |
| Target | Desktop, 1920×1080, ≥60 FPS on a laptop iGPU |
| API compatibility | Use only API stable since **Godot 4.2**, even though the project builds on 4.7 |

## Visual scripting (Godot Orchestrator)

The "no third-party addons" constraint above has one deliberate, owner-decided exception:
**Godot Orchestrator** (`addons/orchestrator/`, a GDExtension-based visual-scripting plug-in,
`CraterCrash/godot-orchestrator`), currently installed on the `orchestrator_test` branch, not yet
merged to `main`/`station_experiments`. Godot 4 dropped its own `VisualScript` at the 4.0 release
with no built-in replacement; Orchestrator fills that gap and is the project owner's tool of choice
for building simple interactive objects without writing GDScript by hand.

**Division of labor**: systems with real state, math, or cross-system coordination (orbital
mechanics, station structure, player locomotion, anything covered by an existing ТЗ) are still
built as GDScript per every convention above, with Claude Code's help as usual. Simple,
self-contained interactive objects — doors, switches, levers, one-off triggers — are built directly
by the project owner as Orchestrator graphs, independently. Don't author or restructure
Orchestrator graphs unprompted; help with them the same way as any other implementation question,
when asked.

**Docs**: a full clone of the official Orchestrator documentation site (Docusaurus source under
`docs/`, not the rendered site) lives outside this repo, since the same plug-in and docs apply to
any Godot project on this machine, not just DYRM:

```
C:\Users\PC\Documents\Development\godot-orchestrator-docs
```

Layout: `docs/getting-started/` (concepts, installation, design philosophy), `docs/nodes/` — one
file per visual-node category (`signals.md`, `flow-control.md`, `functions.md`, `variables.md`,
`scene.md`, `autoloads.md`, `singletons.md`, `resources.md`, `dialogue.md`, `math.md`, `arrays.md`,
`dictionary.md`, `events.md`, `input.md`, `memory.md`, `properties.md`, `utilities.md`,
`constants.md`, `comments.md`, `all_nodes.md`), `docs/about/` (FAQ, requirements, licensing),
`docs/community/`. Use the `godot:godot-orchestrator` skill (grouped in the global `godot` plugin,
`~/.claude/skills/godot/skills/godot-orchestrator/`) when helping with Orchestrator implementation
questions — it knows how this clone is organized and how to search it.

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
- **No autoloads** without explicit justification in a ТЗ. Cross-node references go through
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
one place**, `OrbitalMath.ecliptic_to_godot()` — never duplicate it.

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
global `godot-mcp-testing` skill, grouped in the `godot` plugin
(`~/.claude/skills/godot/skills/godot-mcp-testing/`, invoked as `godot:godot-mcp-testing`; see
Tests section below); check it before improvising a workaround for odd MCP behavior. It's global
(not DYRM-specific) since the same two MCPs and their quirks apply to any Godot project on this
machine — DYRM's own test-case catalog (see Tests below) stays local, in `dyrm-tz`.

## Godot knowledge base (cross-project)

Non-obvious Godot engine/GDScript/MCP behavior that required real diagnosis (not "read the docs and
it worked") is recorded outside this repo, in a knowledge base shared across every Godot project on
this machine — not DYRM-specific:

```
C:\Users\PC\Documents\Development\Claude Common\Knowledge base\Godot\godot-development-knowledge-base.md
```

Before re-diagnosing weird engine/MCP behavior from scratch, check whether it's already recorded
there. Populate it via the global `godot-knowledge-base` skill, grouped in the `godot` plugin
(`~/.claude/skills/godot/skills/godot-knowledge-base/`, invoked as `godot:godot-knowledge-base`)
after finishing and verifying a ТЗ/task, if something non-trivial came up — both the file and the
skill live outside this repo on purpose, since the same findings apply to any Godot project, not
just DYRM.

## External Godot skill library (gd-agentic-skills)

`~/.claude/skills/godot/skills/` (part of the global `godot` skills-directory plugin — see the
global `~/.claude/CLAUDE.md` for how that plugin is organized) also hosts 97 global skills from
`thedivergentai/gd-agentic-skills` (`godot-master` plus domain/genre skills covering GDScript
patterns, architecture, 2D/3D systems, UI, and per-genre blueprints), invoked with the `godot:`
prefix (e.g. `godot:godot-gdscript-mastery`). These are freely available to consult and draw
patterns from for DYRM work, same as any other Godot project — no blanket restriction against
using them.

That said, this file's own sections above (**Tech stack and constraints**, **Code conventions**,
**Coordinates and units**, **Tooling**) are DYRM's deliberate, ТЗ-000-derived source of truth and
win whenever a pattern from that library would conflict with them — e.g. its
`godot-autoload-architecture` skill's autoload-forward patterns don't override "no autoloads
without explicit justification in a ТЗ" above; its `godot-builder` skill's own Python/CLI scripts
for driving Godot headlessly are not this project's workflow — use the `godot-runtime`/`godot` MCP
pair via the `godot:godot-mcp-testing` skill instead. Most of the library's genre blueprints and
platform-adaptation skills (mobile/console/VR/web ports, multiplayer, most `godot-genre-*`) are
simply not applicable to a singleplayer, desktop-only, first-person sim/puzzle game — skip them
rather than forcing fit.

## Tests

ТЗ-000 defines the autotest entry point, `tools/run_tests.gd`:

```bash
godot --headless --path . --script res://tools/run_tests.gd
```

Expected output: one line per test, ending in `RESULT: <N> passed, 0 failed`, exit code 0. Run this
full, unfiltered form as the final regression check before considering a task done.

### Autotests: blocks and point runs

The 42 tests are grouped into 8 semantic blocks, defined by `BLOCK_ORDER` at the top of
`tools/run_tests.gd` (this is the single source of truth for the mapping below — re-read it if the
suite has grown since this was written, don't trust this list blindly):

| Block | Tests | Covers |
|---|---|---|
| `space_scale` | T-01, T-02, T-03, T-11 | `SpaceScale` distance compression/render radius math — no scene |
| `orbital_mechanics` | T-04, T-05, T-06, T-07, T-08, T-10, T-15 | Planet/Triton/station orbits, epoch round-trip, ring rotation period |
| `starfield` | T-16 | `StarfieldBuilder` determinism — no scene |
| `station_structure` | T-09, T-12, T-13, T-14, T-18, T-19 | Station geometry: gravity, AABB, arcs, laser coverage, rotating ring, markers |
| `physics_containment` | T-17 | RigidBody containment inside each module (heaviest single test) |
| `player_locomotion` | T-20 – T-32, T-41 – T-43 | `PlayerController` on the dumbbell station (ТЗ-000 §17.3): orientation, walk/run/jump/step, teleport, determinism, zero-g flight (T-41), truss↔arm transition (T-42), bidirectional walk-speed symmetry under a 180° avatar turn (T-43) |
| `interaction_ui` | T-33 – T-39 | Work panels, viewport mapping, doors/hatches, input capture — currently SKIPped unconditionally: `run_tests.gd` always loads `main.tscn`, which now points at the dumbbell station (ТЗ-000 §17), and no panels/doors/hatches are placed there yet (a separate, not-yet-started task). The old ring scene these tests target (`scenes/station/station.tscn`) still exists and still works, just isn't reachable from this automated suite anymore — only from the `dyrm-tz` skill's live-MCP test cases against `scenes/dev/movement_calibration.tscn` |
| `scene_integrity` | T-40 | Whole-tree invariants (e.g. no stray `AudioStreamPlayer`) |

During iterative work on one subsystem, **run only the affected block plus its immediate neighbors
in `BLOCK_ORDER`** (not the full 40), via a `--blocks=` filter after `--`:

```bash
godot --headless --path . --script res://tools/run_tests.gd -- --blocks=player_locomotion,station_structure
```

`--blocks=` accepts a comma-separated list; an unknown name prints a `WARN` instead of silently
matching nothing. Omitting it (or passing none) runs everything, unchanged from before this option
existed. Skipping unrequested blocks also skips their setup cost, not just their assertions — e.g.
`--blocks=space_scale` never loads `main.tscn` at all, and any run that excludes both
`player_locomotion` and `interaction_ui` and `scene_integrity` skips the ТЗ-100 player-test harness
entirely. `physics_containment` (T-17) and the `player_locomotion` block's stand-still test (T-25,
300 simulated seconds) are the two most expensive parts of a full run — leave them out of point runs
unless they're the block actually being touched.

Point runs are for iteration, not for closing out a task: **always finish with one full,
unfiltered run** (see above) before reporting a fix as verified — a point run only proves the
touched block and its declared neighbors are clean, not the whole suite.

**`T-43`** tracks the with-spin/against-spin walk-speed asymmetry described in the "Tangential-
direction/speed correction" note below and now **passes**, live and headless, after that fix — see
that note (and the comment on `_test_bidirectional_arc_speed()` in `tools/run_tests.gd`) for what was
tried, rejected, and what actually landed. Like everything else on this floor it may still show
occasional headless noise; don't be alarmed by one bad ratio if it doesn't reproduce live.

**Known headless-only failures (updated 2026-07-30 after adding the tangential-drift sign
correction below, unresolved):** `T-24, T-26, T-27, T-28, T-29, T-31, T-32, T-42` — every
`player_locomotion` test that actually walks/runs/jumps on the arm's rotating floor — fail
specifically under `godot --headless --script res://tools/run_tests.gd`, but **the specific subset
that fails now varies run to run** (confirmed empirically: three consecutive full runs on identical
code gave three different pass/fail patterns for T-25/26/27/29/31 — e.g. T-25's radius drift read
2461m on one run and passed cleanly on the next, same binary). This contradicts the earlier note in
this section claiming "deterministic, exactly-repeating numbers" — that was true before the fix
below was added and is **no longer accurate**; treat any single headless run's failing-test list as
one sample from a noisy distribution, not a stable fingerprint, and re-run at least 2-3 times before
concluding a code change fixed or broke a specific numbered test in this family. `T-25` (stand-still)
passes on most runs — don't be alarmed by an occasional large radius-drift number, but don't declare
it "fixed" from one green run either. The same mechanic (`GRAVITY_WALK` in
`player_controller.gd`, physics-based `move_and_slide()`/`is_on_floor()`) is confirmed stable
through extensive live `godot-runtime` MCP testing — standing, walking, running, repeated
stop-start cycles, radius held at 60.00±0.02m, matching the old ring's quality. One contributing
detail found live (not headless-specific — reproduced on both the old ring and the arc room):
`is_on_floor()` takes ~50 physics frames (~0.8s) to first read `true` after every
`teleport_to_module()`, even standing still exactly on the floor. In live play this is harmless —
`is_on_floor()` starts flickering `true` often enough afterward for the radial pin (see
`_physics_process_gravity_walk()`) to keep firing and hold the radius. In the *headless* T-24 run,
`is_on_floor()` never once reads `true` in 300 frames (`grounded_bad_frames=300/300`) — not merely
"a slower first grounding" but a total absence of the flicker seen live — so the pin never fires
and the radius drifts freely. Whether that 100%-headless-ungrounded state is the same underlying
mechanism as the ~50-frame live delay, just worse, or a distinct bug, is **not established** — see
the comment block above `_run_player_tests()` in `tools/run_tests.gd` for what was investigated and
ruled out (docking registration, floor segmentation, epoch jump, T-23 ordering) before treating this
as a live-verified gameplay fix with an open headless-test-harness gap, not a suspected regression.
`T-28` (step threshold) is a separate, older, unrelated known limitation — see its own comment in
the same file.

**Tangential-direction/speed correction (2026-07-30):** live gameplay testing surfaced two related,
genuinely user-visible bugs on the arc room floor — (1) walking backward (or strafing) could
net-travel in the *same* direction as forward, not just slower, and (2) walking *with* the arm's own
spin direction was noticeably faster and jerkier than walking *against* it (confirmed via a
180°-avatar-turn methodology, not just flipping `set_move_input`'s sign, which doesn't isolate
world/ring-space direction from input-sign handling — see `T-43`, block table and
`tools/run_tests.gd`). Root cause for both: `move_and_slide()`'s resolved tangential displacement
against the rotating floor is occasionally flat-out reversed, or in the with-spin case several times
*longer* than intended, relative to `horizontal_velocity`'s target (`get_platform_velocity()` was
observed swinging between 0, 1×, and 2× the ring's true tangential speed frame to frame — Jolt
double-counting/dropping the platform's rotation on contact resolution). Fixed in
`_physics_process_gravity_walk()`: when `move_and_slide()`'s actual tangential displacement either
opposes the intended one, or is more than `EXCESS_TANGENTIAL_SPEED_MULTIPLIER` (2×) longer than it,
replace it with the analytical `ring_basis * horizontal_velocity * delta` — a short (not longer than
intended) same-direction result is left untouched so wall-blocking still works (see the regression
check at the arc room's end wall). Live-verified: with-spin/against-spin ratio dropped from ~2.5-6x to
~1.1-1.6x across repeated trials, both directions' magnitude now sane (matches `walk_speed_m_s`
instead of inflating 4-9x).

Two *earlier*, narrower/broader variants of this same idea were tried first and reverted, based on
what turned out to be a **false read of the old ring's baseline determinism**: repeated identical
input on `movement_calibration.tscn` was assumed to be reliably reproducible (based on one early
single-trial check), so any variant that made repeated trials disagree was treated as a regression
this fix introduced. Multi-trial testing later showed the **unmodified, pre-session old-ring code**
already produces this same trial-to-trial spread (including sign flips) with zero code changes —
the fragility is a pre-existing property of Jolt's contact resolution against a continuously-rotating
`AnimatableBody3D`, not something introduced by this fix. Don't re-litigate this fix's safety by
comparing against an assumed-stable old-ring baseline without first re-confirming that baseline is
actually stable via several repeated trials of your own — it may not be.

A **third** live report followed after the above landed: a brief tap of a movement key (press then
immediately release) produced a sharp jerk toward the arm's spin direction right at the start of
motion — both forward and backward taps jerked the same way — after which holding the key became
smooth. Root cause: the `reversed`/`excessive` checks above both gate on `intended_len_sq > 0.0001`,
but `horizontal_velocity` (and therefore `intended_horizontal`) is still near zero for the first
frame or two of any tap — it hasn't ramped up through `move_toward()` yet — so the gate skipped the
check entirely on exactly the frames where a stray Jolt contact-resolution spike was most visible.
Fixed by adding a third, unconditional check: `actual_horizontal.length() > config.run_speed_m_s *
MAX_VELOCITY_SPEED_MULTIPLIER * delta` (an absolute per-frame cap, independent of what was
"intended" that specific frame) — see the comment at the call site. Live-verified across settled and
freshly-spawned starts, both directions: max per-frame displacement now stays under the
`walk_speed_m_s`-implied ceiling in every sampled case, no discontinuity at tap start or release.

A **fourth** live report followed: the player could walk straight through the arc room's end
walls and fall out of the station entirely. Root cause: the `reversed`/`excessive` checks above
can't tell "Jolt's usual rotating-floor contact glitch" from "the player legitimately hit a wall and
got pushed back" — both look like `actual_horizontal` opposing or falling short of
`intended_horizontal`. Once the player reached an end wall, the correction kept overriding the
correctly-blocked position with the full-speed analytical one, shoving them straight through
(confirmed live: player reached `φ=-43°` against a `±30°` boundary, `on_floor=false`, radius ~120m
— fully outside the module — while `get_slide_collision()` showed real wall contacts the whole
time being discarded). Fixed by checking `get_slide_collision()` each frame the correction would
fire: if any collision normal's dot product with `_up_global` falls below
`WALL_NORMAL_DOT_THRESHOLD` (0.5) — i.e., the surface isn't the floor/ceiling — skip the correction
entirely for that frame and trust Jolt's blocked result. Floor normals (even on the faceted,
chord-segmented floor) stay within a few degrees of `up_global`; wall normals are roughly
perpendicular. Live-verified: player now stops cleanly at `φ≈29.3°`, radius still pinned at
~60m — no more walking through the end wall — while all four walk directions and the tap-start
fix above remain unaffected.

**All testing during development beyond this headless numeric run goes through two skills split
by scope** — don't improvise MCP verification steps ad hoc:

- **`godot-mcp-testing`** (global, grouped in the `godot` plugin at
  `~/.claude/skills/godot/skills/godot-mcp-testing/`, invoked as `godot:godot-mcp-testing` — not
  DYRM-specific, same as any Godot project using this MCP pair): general MCP process/lifecycle discipline, the full
  tool catalog for both MCPs, scene-authoring/runtime tool gotchas, the calibration-scene recipe,
  screenshots, live-bridge-vs-autotests.
- **`dyrm-tz`** (`.claude/skills/dyrm-tz/`, DYRM-specific): the test-case catalog itself — a
  reusable card template (`references/test-case-template.md`) and per-ТЗ catalogs
  (`references/tz-NNN-test-cases.md`), covering acceptance-criteria types that need a live project
  (`рантайм-авто`, `визуально`) plus a regression watch-list of already-known spec deviations.
  These are the canonical test cases for that ТЗ — consult and update them instead of re-deriving
  verification steps from scratch. See that skill's "Зафиксировать реализацию" step for when to
  add or update a ТЗ's catalog, and its own "Тест-кейсы: шаблон и каталог" section for the
  run/create handlers.

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
