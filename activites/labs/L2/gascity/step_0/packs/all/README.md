# actual-factory (composition pack)

For this L2 checkpoint, this composition pack imports only the two
leaf packs exercised by the L2 lab — architect and planner — via
`[imports.<binding>]` entries in `pack.toml`.

## Usage

In the checkpoint's `city.toml.template`:

```toml
[workspace]
name = "l2-step-0-factory"
provider = "claude"
default_rig_includes = ["./all"]
```

`./all` expands to architect + planner via its own `pack.toml`
`[imports.*]` entries, so every rig registered with `gc rig add`
gets both agents automatically.

## The 2 agents shipped in L2

| Operation | Pack | Label gate |
|-----------|------|------------|
| Architect | `../architect` | `needs-architecture` |
| Plan / Work Breakdown | `../planner` | `needs-plan` |

The full 8-agent factory lives in the canonical `packs/all/` at repo
root; this L2 checkpoint ships only what the lab exercises.

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
