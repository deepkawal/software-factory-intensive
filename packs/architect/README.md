# actual-architect

The **Architect** agent of the Actual Software Factory. One of eight
Agent-Operation packs under `packs/`. Maps to the "Architect" operation
at https://www.actual.ai/softwarefactory.

## Persona

Principal Engineer + Solutions Architect. Prioritizes simplicity over
cleverness. Documents the *why* behind decisions. Thinks in trust
boundaries, access controls, guardrails, and end-to-end trade-offs.
Anchor personas are defined in
`actual-factory/extensions/factory-vscode/shared/actual-agents/built-in-agents.ts`.

## What it does

- Reads beads labelled `needs-architecture`
- Uses the bundled **actual** skill to run `actual adr-bot` and keep
  `CLAUDE.md` / `AGENTS.md` in sync with the rig's ADRs
- Writes one-page guardrail rules under `.actual/rules/<topic>.md`
- Hands off to the **planner** by creating child beads with the
  `needs-plan` label

## What it does NOT do

Write implementation code. Decompose work. Run CI. Review PRs.

## How to run

As part of the full factory (from `my-factory/`):
```bash
gc rig add /path/to/your/project
gc restart
```

Standalone (just this agent), in a factory `pack.toml`:
```toml
[imports.architect]
source = "../packs/architect"
```

Manual dispatch of the formula against a specific bead:
```bash
gc sling <rig>/architect --on mol-architect-review \
    --var topic=auth-boundaries
```

## Pack contents

| Path | Purpose |
|------|---------|
| `pack.toml` | Pack identity (v2 — schema=2) |
| `agents/architect/agent.toml` | Agent scope, wake mode, work dir, nudge, session limits |
| `agents/architect/prompt.template.md` | The Principal-Engineer persona prompt |
| `agents/architect/overlay/.claude/settings.json` | Claude Code session settings |
| `agents/architect/overlay/.claude/skills/actual/` | Vendored upstream actual-skill |
| `formulas/mol-architect-review.toml` | 5-step review workflow |
| `orders/architect-guardrail-check.toml` | Condition-gated auto-dispatch |
| `commands/status/run.sh` + `command.toml` | `gc architect status` — work queue |
| `commands/rules/run.sh` + `command.toml` | `gc architect rules` — list rules |
| `doctor/check-architect/run.sh` + `doctor.toml` | Verifies `bd`, `gc`, `git`, `jq`, `actual` |
| `assets/sync-actual-skill.sh` | Author tool: re-vendor upstream actual-skill |

## Updating the vendored actual-skill

The `agents/architect/overlay/.claude/skills/actual/` tree is a verbatim
copy of `skills/actual/` from
[actual-software/actual-skill](https://github.com/actual-software/actual-skill).
When upstream publishes a new version:

```bash
./assets/sync-actual-skill.sh            # pulls main
./assets/sync-actual-skill.sh v1.2.3     # pins to a tag
git diff -- agents/architect/overlay/.claude/skills/actual
```

Review and commit the diff.

The skill is duplicated under each agent's overlay rather than shared from
a pack-root `skills/` directory because Gas City 0.15.x only materializes
overlay content into sessions — see
[workshop comment on gastownhall/gascity#669](https://github.com/gastownhall/gascity/issues/669).

## Handoff protocol

```
architect (this pack)  →  planner  →  designer/validator  →  builder
                                                                ↓
                                                             reviewer
                                                                ↓
                                                          release-gate
                                                                ↓
                                                            improver
                                                                ↓
                                                           (loop back)
```

Each step advances via a label change on the bead. No Go code, no
hardcoded pipeline — just beads and label-matching order gates. The
formula's handoff step calls `gc all wake-downstream &` to nudge the
next agent whose label just became ready.
