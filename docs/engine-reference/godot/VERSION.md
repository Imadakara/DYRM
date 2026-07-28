# Godot — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | 4.7 (Forward+ renderer) |
| **Project Pinned** | 2026-07-25 (project.godot creation — predates plugin adoption) |
| **LLM Knowledge Cutoff** | January 2026 (Claude Sonnet 5) |
| **Risk Level** | LOW-MEDIUM — mitigated by project convention, see Note |

## Note

The project deliberately writes to a lower API floor than the pinned engine version:
**only API stable since Godot 4.2** is used, even though the project builds on 4.7.
This was adopted in ТЗ-000 (2026-07-26) specifically to make the version gap between
"what the engine is" and "what the LLM reliably knows" a non-issue — new code should
default to this floor rather than to bleeding-edge 4.6/4.7 APIs.

No breaking-changes/deprecated-APIs reference set has been generated from a web
search — the 4.2-floor convention above is the project's chosen mitigation instead.
If an agent hits an actual 4.2→4.7 API gap during implementation, treat it as a
signal to run `/setup-engine refresh` and populate the fuller reference set at
that point, rather than guessing.

Run `/setup-engine refresh` to populate full reference docs (breaking-changes.md,
deprecated-apis.md, current-best-practices.md) at any time.
