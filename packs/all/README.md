# actual-factory (composition pack)

Brings up all 8 Agent Operations of the Actual Software Factory in one
import. Depends on the 8 sibling leaf packs under `packs/`.

## Usage

In the factory's root `pack.toml`, import this pack at workspace scope
(required to expose the `gc all wake-downstream` command — see
[workshop:#786](https://github.com/gastownhall/gascity/issues/786)):

```toml
[pack]
name = "my-factory"
schema = 2

[imports.all]
source = "../packs/all"
```

In the factory's `city.toml`, include the same pack via
`default_rig_includes` so every `gc rig add` auto-stamps rig-scope agents
(workaround for [workshop:#779](https://github.com/gastownhall/gascity/issues/779)
and [workshop:#781](https://github.com/gastownhall/gascity/issues/781) —
hot-reload coverage and v2 default-rig-imports shape unresolved):

```toml
[workspace]
name = "my-factory"
default_rig_includes = ["../packs/all"]
```

The dual-import is a workaround, not a preference — see the linked
issues.

## The 8 agents

| Operation | Pack | Label gate |
|-----------|------|------------|
| Architect | `../architect` | `needs-architecture` |
| Plan / Work Breakdown | `../planner` | `needs-plan` |
| UI/UX Design | `../designer` | `needs-design` |
| Validate / Test Cases | `../validator` | `needs-tests` |
| Build Code | `../builder` | `ready-to-build` |
| Code Review | `../reviewer` | `needs-review` |
| Deploy / Release Gate | `../release-gate` | `ready-to-ship` |
| Improve / Feedback Loop | `../improver` | cooldown (24h) |

## Handoff flow

```
(user or tracker issue)
    │
    ▼  needs-architecture
architect  ───────────►  needs-plan  ─►  planner
    ▲                                      │
    │ (hand-back)                          ▼
    │                          needs-design / needs-tests / ready-to-build
    │                                      │
    │                      ┌───────────────┼───────────────┐
    │                      ▼               ▼               ▼
    │                  designer       validator         builder
    │                      │               │               │
    │                      └───►           └───►           │
    │                      ready-to-build  ready-to-build  │
    │                                                      ▼
    │                                              needs-review
    │                                                      │
    │                                                      ▼
    │                                                  reviewer
    │                                            ┌─────────┴─────────┐
    │                                            ▼                   ▼
    │                                  ready-to-build           ready-to-ship
    │                                  (back to builder)             │
    │                                                                ▼
    │                                                         release-gate
    │                                                                │
    │                                                                ▼
    │                                                         needs-improve
    │                                                                │
    │                                                                ▼
    │                                                           improver
    │                                                                │
    └────────────────────────────────────────────────────────────────┘
                          (loop back to any upstream agent)
```

## Why this is a pack and not a master formula

The whole factory runs on **label-based handoff**. There is no master
orchestrator, no pipeline DAG hardcoded anywhere. Each pack's order
gate watches for its own label. Rewire the flow by changing labels,
not by editing Go or TOML.

This honors Gas City's core invariant: **ZERO hardcoded roles**.
Every leaf pack is self-describing. This composition pack just
bundles them for convenience.

## The `wake-downstream` pack command

Every leaf pack's formula handoff step runs `gc all wake-downstream &`
after closing its root bead. That command lives at
`commands/wake-downstream/run.sh` here; its body scans for ready beads
on each downstream label (`needs-plan`, `needs-design`, etc.) and slings
them to the matching agent.

It's packaged as a pack command rather than a `scripts/*.sh` path because
Gas City 0.15.x doesn't expose `$PACK_DIR` in agent session shells — a
relative path would be topology-coupled. See [workshop:#785](https://github.com/gastownhall/gascity/issues/785)
for the upstream gap.
