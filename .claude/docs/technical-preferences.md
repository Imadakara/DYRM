# Technical Preferences

> Generated during full adoption of the `gamedev` Claude Code plugin (see
> `docs/adoption-plan-2026-07-28.md`). Values below reflect the tech stack already
> pinned by ТЗ-000 (2026-07-26) — this file formalizes decisions made before the
> plugin was adopted, it does not introduce new ones.

## Engine & Language
- **Engine**: Godot 4.7 (Forward+ renderer)
- **Language**: GDScript
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline (no third-party addons)
- **Physics**: Jolt Physics
- **Graphics Driver**: D3D12 (Windows)
- **API Compatibility Floor**: Only API stable since Godot 4.2, even though the project builds on 4.7 — this is the project's own mitigation for building on a version newer than the LLM's reliable knowledge, see Engine Reference below.

## Naming Conventions
- Classes/nodes: PascalCase (e.g. `PlayerController`)
- Variables/functions: snake_case (e.g. `move_speed`)
- Signals: snake_case, past tense (e.g. `health_changed`)
- Files: snake_case matching class (e.g. `player_controller.gd`)
- Scenes: PascalCase matching root node (e.g. `PlayerController.tscn`)
- Constants: UPPER_SNAKE_CASE (e.g. `KM_PER_AU`)
- Identifiers in English; comments explaining formulas and physical constants are written **in Russian** (project convention, see CLAUDE.md)
- Requirement IDs referenced in comments where useful (`# FR-12`); deferred work marked `TODO(ТЗ-NNN)` — legacy ТЗ numbering is kept for historical cross-reference even as new work moves to TR-IDs

## Input & Platform
- **Target Platforms**: PC (desktop only)
- **Input Methods**: Keyboard/Mouse
- **Primary Input**: Keyboard/Mouse
- **Gamepad Support**: None
- **Touch Support**: None
- **Platform Notes**: Target is a laptop-class iGPU, 1920×1080, ≥60 FPS (ASUS VivoBook-class reference machine, integrated or low-end discrete graphics).

## Performance Budgets
- **Target Frame Rate**: 60 FPS
- **Frame Budget**: 16.6 ms
- **Triangle Budget**: ≤200,000 triangles/scene (ТЗ-000 NFR-09)
- **Asset Budget**: ≤50 MB/scene (ТЗ-000 NFR-09)
- **No allocations in hot `_process` loops** (project-wide convention)

## Testing
- **Framework**: Custom headless test runner — `godot --headless --path . --script res://tools/run_tests.gd`
- **Output contract**: one line per test, final line `RESULT: <N> passed, <M> failed`, non-zero exit code on any failure
- **Manual/visual/runtime evidence**: via the `godot-runtime`/`godot` MCP pair, per the global `godot-mcp-testing` skill

## Forbidden Patterns
- No autoloads without explicit justification recorded in an ADR (was: "in a ТЗ" — pre-adoption phrasing, same rule)
- No numeric literals in scripts except universal constants (`KM_PER_AU`, `G`, `TAU`) — all tunable parameters live in `.tres` resources
- No `Resource`-in-`Resource` nesting deeper than one level
- No cyclic `preload`, no parse-time dependency on an autoload
- No third-party addons or GDExtension

## Allowed Libraries
- None beyond stock Godot 4.7 modules (Jolt Physics is a built-in physics backend, not a third-party addon)

## Engine Specialists
- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all `.gd` files)
- **Shader Specialist**: godot-shader-specialist (`.gdshader` files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (not expected to be used — project is GDScript-only by ТЗ-000 constraint, listed for completeness only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code.

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (`.gd` files) | godot-gdscript-specialist |
| Shader / material files (`.gdshader`, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (`.tscn`, `.tres`) | godot-specialist |
| General architecture review | godot-specialist |
