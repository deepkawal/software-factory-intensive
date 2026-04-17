# Actual Software Factory — Gas City Agent Packs

A self-contained set of Gas City agent packs (Pack v2, `schema = 2`) implementing the 8 Agent Operations described at [actual.ai/softwarefactory](https://www.actual.ai/softwarefactory):

1. **Architect** — set architectural rules; access controls, trust boundaries, guardrails
2. **Plan / Work Breakdown** — create work packages from high-level goals
3. **UI/UX Design** — wireframes, design systems, a11y audits
4. **Validate / Test Cases** — write failing tests from acceptance criteria
5. **Build Code** — implement against the test suite
6. **Code Review** — automated review for style, security, spec compliance
7. **Deploy / Release Gate** — quality gate with rollback plan
8. **Improve / Feedback Loop** — runtime signals back into the spec

Each operation is one pack. Each pack is a single Gas City agent with its own `agents/<n>/` directory (v2 convention), formula, order gate, doctor check, and commands. `all/` is a composition pack that imports all 8 leaves and hosts the `gc all wake-downstream` pack command every handoff step invokes.

## Directory layout

```
packs/
├── README.md                # you are here
├── architect/               # Principal-Engineer persona
├── planner/                 # Product-Manager + Program-Manager persona
│                            # (ships the tracker-to-beads bridge skill)
├── designer/                # UI/UX-Designer + Accessibility-Engineer persona
├── validator/               # QA-Engineer persona
├── builder/                 # Backend+Frontend generalist persona
├── reviewer/                # Engineering-Manager + Principal-Engineer +
│                            # Security-Engineer persona
├── release-gate/            # Release-Engineer + DevOps-Engineer persona
├── improver/                # SRE + Performance-Engineer + DevRel persona
├── all/                     # Composition pack; hosts gc all wake-downstream
├── fired-up-pizza/          # Composite pack for the reference project
└── workshop/                # Pre-configured tracker/observability integrations
```

Each agent pack has the v2 shape:

```
<pack>/
├── pack.toml                          # [pack] name + schema = 2
├── README.md
├── agents/<name>/
│   ├── agent.toml                     # scope, wake_mode, work_dir, nudge, limits
│   ├── prompt.template.md             # persona + workflow prompt
│   └── overlay/.claude/
│       ├── settings.json              # Claude Code session settings
│       └── skills/                    # vendored skills (per-agent; see below)
├── commands/<cmd>/
│   ├── command.toml                   # description
│   └── run.sh                         # gc <pack> <cmd> entrypoint
├── doctor/<check>/
│   ├── doctor.toml                    # description
│   └── run.sh                         # gc doctor check body
├── formulas/<name>.toml               # step-based workflow definitions
├── orders/<name>.toml                 # label-gated auto-dispatch
└── assets/                            # helper scripts (maintainer tools only)
```

## Persona mapping

The agent voices are anchored to the built-in personas from the Actual Factory VS Code extension's `built-in-agents.ts`:

| Pack | Anchor persona(s) |
|------|-------------------|
| architect | `principal-engineer` + `solutions-architect` |
| planner | `product-manager` + `program-manager` |
| designer | `ui-ux-designer` + `accessibility-engineer` |
| validator | `qa-engineer` |
| builder | `backend-engineer` + `frontend-engineer` |
| reviewer | `engineering-manager` + `principal-engineer` + `security-engineer` |
| release-gate | `release-engineer` + `devops-engineer` |
| improver | `sre` + `performance-engineer` + `developer-advocate` |

## The actual-skill integration

Three packs — **architect**, **planner**, **builder** — vendor the upstream [actual-software/actual-skill](https://github.com/actual-software/actual-skill) Claude Code companion for the `actual` CLI (ADR-powered CLAUDE.md/AGENTS.md generator). Each pack ships its own copy under `agents/<name>/overlay/.claude/skills/actual/`.

**Why per-agent duplication?** Gas City 0.15.x only materializes overlay content into agent sessions — pack-root `skills/` and per-agent `agents/<n>/skills/` are discovered but not staged. See the workshop comment on [gastownhall/gascity#669](https://github.com/gastownhall/gascity/issues/669) for details. When skills attachment lands upstream, we'll consolidate to one copy.

To re-vendor after upstream releases a new version:

```bash
cd packs/architect && ./assets/sync-actual-skill.sh
cd packs/planner   && ./assets/sync-actual-skill.sh
cd packs/builder   && ./assets/sync-actual-skill.sh
```

The three packs use the skill slightly differently:

- **architect** runs `actual adr-bot --dry-run --full` to keep ADRs and generated rules in sync
- **planner** reads `CLAUDE.md` / `AGENTS.md` for architectural context when breaking down work
- **builder** runs `actual status` before coding to verify the rig is not in ADR drift (and hands the work back to the architect if it is)

## The tracker → beads bridge (planner only)

The planner pack ships a second, pack-local skill: `tracker-to-beads`. This skill probes `.claude/skills/` for any sibling matching `jira`, `linear`, `github-issues`, or `tracker-*` and calls its `list-issues` verb to materialize each external issue as a bead. The mapping is recorded idempotently in `.actual/planner/tracker-sync.json`.

**The builder downstream only ever reads beads** — tracker credentials, API quirks, and rate limits are entirely the sibling tracker skill's problem. The rest of the factory is tracker-agnostic.

If no tracker skill is installed, the step is a no-op and the planner just breaks down whatever beads already exist. Users run the factory in pure bd-first mode, hybrid mode, or tracker-first mode without touching any config.

See [`planner/README.md`](planner/README.md) for the sibling-skill contract (`scripts/list-issues.sh` printing a JSON array).

## Handoff protocol

There is **no master orchestrator**. Each pack's order gate matches on a bead label; the flow is emergent from labels, not hardcoded:

```
           needs-architecture           needs-plan
(user) ────────────────────► architect ──────────► planner
                                 ▲                    │
                                 │ (drift hand-back)  │
                                 │                    ▼
                                 │         ┌──────────┬──────────┐
                                 │         ▼          ▼          ▼
                                 │    needs-design  needs-tests ready-to-build
                                 │         │          │          │
                                 │    designer    validator      │
                                 │         │          │          │
                                 │         └──────────┴──────────┘
                                 │                    │
                                 │                    ▼  ready-to-build
                                 │               builder
                                 │                    │
                                 │                    ▼  needs-review
                                 │               reviewer
                                 │          ┌─────────┴─────────┐
                                 │          ▼                   ▼
                                 │   ready-to-build       ready-to-ship
                                 │   (back to builder)         │
                                 │                             ▼
                                 │                      release-gate
                                 │                             │
                                 │                             ▼  needs-improve
                                 │                        improver (24h cooldown)
                                 │                             │
                                 └─────────────────────────────┘
                                       (route upstream)
```

After any agent closes its root bead, its formula's handoff step runs `gc all wake-downstream &` — a pack command on `packs/all/` that scans for ready beads on each downstream label and slings them to the matching agent. Rewire the flow by changing labels, not by editing Go or TOML. This honors Gas City's core invariant: **ZERO hardcoded roles**.

## How to run

From `my-factory/` (the factory workspace):

```bash
# 1. Register the factory (once per machine)
cd my-factory
gc register .

# 2. Add your project as a rig — all 8 packs compose via default_rig_includes
gc rig add ~/Projects/your-project

# 3. Start
gc restart
gc status

# 4. File a goal to kick things off (from inside your rig)
cd ~/Projects/your-project
bd create --title "Build user profiles" --label needs-architecture
```

The architect's order gate matches `needs-architecture`, wakes the architect, which runs `mol-architect-review`, produces rules and child beads labelled `needs-plan`, which wakes the planner, and so on.

## Standalone use

Each leaf pack works on its own. In a factory `pack.toml`:

```toml
[pack]
name = "mycity"
schema = 2

[imports.builder]
source = "../packs/builder"
```

Workspace-scope imports expose pack commands (`gc builder <cmd>`). For rig-scope agent materialization, also set `default_rig_includes` in the city's `[workspace]`.

## Principles honored

- **ZERO hardcoded roles** — no Go is touched; role names live only in pack.toml and prompt templates.
- **GUPP** — prompts include "If you find work on your hook, YOU RUN IT" phrasing in the startup section.
- **ZFC** — formulas describe *structure* (step DAG), not judgment. All decision-making lives in the markdown step descriptions.
- **NDI** — `wake_mode = "fresh"` + state-in-beads means every wake re-derives state from durable storage.
- **No status files** — `status.sh` commands query `bd` live, never read cached state files.
- **Label-based handoff** — the pipeline is emergent from order gates + bead labels, never hardwired.
