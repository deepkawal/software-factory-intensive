# Portable state and two-machine protocol

## What Git carries

- `pack.toml.template`, `city.toml.template`, and `bootstrap/city.toml.template`
- agents, formulas, orders, prompts, hooks, scripts, and checked-in skills
- the product repository and ordinary source branches

Runtime `pack.toml` and `city.toml` are generated per machine because Gas City
may add machine-local rig records and cached import pins.

## What Dolt carries

- Beads issues, dependencies, status, ownership, notes, and durable memories
- one remote branch under `refs/dolt/data` in each repository remote

The local Dolt database is the source used by `bd`; `.beads/issues.jsonl` is only
an export. Synchronize with `bd dolt pull/push` or the city-wide `gc dolt
pull/sync` wrappers.

Before the first pull, match `gc`, `bd`, and `dolt` to
`bootstrap/toolchain.env`. A Beads release can migrate the database schema, so
upgrades must be coordinated across both machines. Installing the newest client
on only one host is not a safe shortcut.

## What stays local

- GitHub, Claude, Codex, and provider credentials
- local approval and permission choices
- transcripts, shell snapshots, logs, caches, and usage databases
- `.gc/`, `packs.lock`, `.beads/dolt/`, and `.beads/embeddeddolt/`
- absolute paths and WSL usernames

The checked-in `factory-manager` skill contains the reusable operating behavior.
Project facts that all agents need belong in `bd remember`. Do not bulk-copy
Claude or Codex history: promote only durable, non-secret rules into Beads or a
reviewed skill/reference file.

## Initial Dolt recovery

Machine A must publish both databases before machine B runs bootstrap. The
course repository already owns its `refs/dolt/data` for the top-level `sfi`
tracker, so the nested factory HQ (`mf`/`hq`) requires a **dedicated private Git
repository**. One Git remote cannot independently host both databases at the
same ref. Audit each store first:

```bash
bd dolt remote list
bd dolt pull
bd doctor
```

The product rig's expected remote is its GitHub source repository, expressed
using Beads' `git+https://...` or `git+ssh://...` form. The HQ expected remote is
the dedicated state repository chosen by the operator. If a remote exists but
differs, stop and ask before changing it.

The currently expected machine-A repairs are:

```bash
cd /path/to/software-factory-intensive/my-factory
# Human checkpoint: create an empty private repository dedicated to HQ state.
bd dolt remote add origin git+ssh://git@github.com/<owner>/<factory-hq-state>.git
bd doctor
bd dolt commit -m "publish factory Beads state"
bd dolt push
git ls-remote origin refs/dolt/data

cd /path/to/ai-productivity-repo/ai_meal_planner
bd dolt remote list
bd doctor
# Review the proposed repair before accepting it:
bd doctor --fix
bd dolt commit -m "publish product Beads state"
bd dolt push
git ls-remote origin refs/dolt/data
```

Stop if `bd doctor --fix` proposes anything broader than reconciling the
transport-side remote. Do not use `--force`.

## Duplicate-work prevention

Background convergence runs every two minutes. Claims still need an immediate
round trip:

1. Machine A runs `gc dolt pull`.
2. Machine A claims the bead atomically with `bd update <id> --claim`.
3. Machine A runs `bd dolt commit -m "claim <id>"` and `gc dolt sync`.
4. Machine B runs `gc dolt pull` before selecting work and confirms the bead is
   no longer returned by `bd ready`.

Use separate Git branches or worktrees for code. Beads synchronization does not
merge source files, and a Git push does not synchronize Beads.

Set distinct identities, for example `deepkawal-machine-a` and
`deepkawal-machine-b`. More importantly, partition work by whole top-level
beads or workflow lanes. Keep an unassigned machine's rig suspended; a two-minute
background sync is not a distributed lock for two controllers polling the same
ready queue.

## Acceptance test

```bash
gc dolt pull
bd show <known-id>
gc order show beads-converge
gc order run beads-converge
gc dolt sync
gc doctor
bd doctor
gc config explain --rig ai_meal_planner
gc start --dry-run
```

Then create or claim a disposable test bead on one machine, sync it, pull on the
other machine, and confirm its exact status and assignee. Close the disposable
bead and repeat the round trip.

Only after that test succeeds, run `gc rig resume ai_meal_planner` on the
machine that owns an explicitly assigned lane. Leave the other machine's rig
suspended unless it has a different assigned lane.
