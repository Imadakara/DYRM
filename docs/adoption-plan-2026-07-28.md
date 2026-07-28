# Adoption Plan — DYRM full pipeline switch to the `gamedev` plugin

> **Generated**: 2026-07-28
> **Project phase**: Production (two MVP systems shipped: 000, 100)
> **Engine**: Godot 4.7 (GDScript)
> **Outcome**: Complete — this is a record of what was migrated, not a pending plan.

## Why this document exists

`/gamedev:adopt`'s standard audit assumes a project that already lives partly in
the plugin's expected layout (`design/gdd/`, `docs/architecture/`,
`production/epics/`) but has format gaps. DYRM had none of that — design work
existed in a completely separate sibling repo (`DYRM Docs`) using its own ГДД→ТЗ
template. This was a **content migration**, not a format-compliance fix, so the
work below was done directly rather than through the standard BLOCKING/HIGH/
MEDIUM/LOW gap-remediation flow.

Decisions confirmed with the user before starting:
- **Backfill depth for systems 000/100**: Full backfill — proper per-system GDDs,
  retrofit ADRs for the real architecture decisions already made, and retroactive
  Done stories, so `tr-registry`/traceability/control-manifest are correct from
  day one.
- **Old pipeline disposition**: Retire it — CLAUDE.md's workflow section now
  describes the gamedev plugin pipeline as the sole process going forward;
  `dyrm-tz` and the old ТЗ docs remain untouched in the vault as historical
  reference, no longer part of the active workflow.
- **Review mode**: `lean` — director specialists only at `/gate-check` phase
  gates, not at every skill step.

## What was migrated

| Source (DYRM Docs vault, ГДД→ТЗ format) | Destination (this repo, gamedev plugin format) |
|---|---|
| `Идея игры - DYRM.md` | `design/gdd/game-concept.md` |
| `ГДД - Перечень систем.md` | `design/gdd/systems-index.md` (53 systems, valid status vocabulary, ТЗ-derived `NNN` numbering preserved) |
| `ТЗ/ТЗ-000 — Игровое окружение.md` | `design/gdd/000-igrovoe-okruzhenie.md` (Status: Approved) |
| `ТЗ/ТЗ-100 — Игрок и станция от первого лица.md` | `design/gdd/100-igrok-i-stancia-ot-pervogo-lica.md` (Status: Approved) |
| Architecture decisions embedded in both ТЗ + CLAUDE.md | 4 new ADRs (`docs/architecture/adr-0001..0004`), `docs/registry/architecture.yaml` |
| FR/AC tables in both ТЗ | `docs/architecture/tr-registry.yaml` (18 TR-IDs), Acceptance Criteria sections of both new GDDs |
| — (new artifact, no prior equivalent) | `docs/architecture/control-manifest.md` |
| ТЗ-000/ТЗ-100 §16 "Итог реализации" (implementation status + deviations) | 2 epics, 8 retroactive Done stories under `production/epics/`, each preserving documented deviations (drift, FR-51 gap, door-geometry gap) |
| — | `.claude/docs/technical-preferences.md`, `docs/engine-reference/godot/VERSION.md` |
| — | `production/sprint-status.yaml` (Sprint 0, retroactive), `production/stage.txt` (`Production`), `production/review-mode.txt` (`lean`) |
| CLAUDE.md "Two-repository split" + "Writing/updating ТЗ specs" sections | CLAUDE.md "Development pipeline (gamedev plugin)" section |

No new design decisions were made in this port — every value, formula, requirement,
and architectural stance above already existed in the shipped ТЗ documents or in
CLAUDE.md. The two new GDDs and four ADRs are reformattings, not redesigns.

## What did NOT change

- The original `DYRM Docs` vault (`Идея игры - DYRM.md`, `ГДД - Перечень систем.md`,
  `ТЗ/ТЗ-000...md`, `ТЗ/ТЗ-100...md`, `ТЗ/_ШАБЛОН ТЗ.md`) — left untouched as the
  historical, more detailed implementation record.
- `.claude/skills/dyrm-tz/` — left untouched, no longer used for new work.
- Any shipped code (`src/`, `scenes/`, `resources/`) — this was a documentation/
  process migration only, zero code changes.
- Tech stack, code conventions, coordinate system, MCP tooling facts in CLAUDE.md
  — unchanged in substance, only re-homed to reference the new ADRs where useful.

## Next step

The next system to actually design and implement going forward is the first
undesigned MVP system in `design/gdd/systems-index.md`'s Recommended Design
Order: **021 — Приём входящих сообщений**. Run
`/design-system 021-priem-vhodyaschih-soobscheniy` to start it through the new
pipeline (GDD → ADR as needed → epic → stories → `/dev-story`).

## Re-verification

Re-run `/gamedev:project-stage-detect` or `/gamedev:adopt` at any time to confirm
the migrated artifacts remain consistent with what the plugin's skills expect.
