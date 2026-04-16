# Port entire repo to Pack v2 (pack-vnext)

## Context

Gas City 0.15.x introduces **Pack v2** (a.k.a. `pack-vnext`, `packsv2`), which splits the old monolithic `city.toml`/`pack.toml` (schema=1) into portable **pack definitions** (`pack.toml` + per-entity directories) and **deployment state** (`city.toml` + `.gc/`). Migration guide: https://docs.gascityhall.com/guides/migrating-to-pack-vnext.

This repo is entirely on v1 (`schema = 1` in every `pack.toml`; no `vnext`/`v2` artifacts). The tutorial pins **gascity 0.14.1** and uses `rsync` to copy-install packs, both incompatible with v2.

**Goal:** migrate the entire repo — every pack, every city, and all supporting tutorial/curriculum material — to v2 layout. Drop the 0.14.1 pin, depend on gascity 0.15+, replace rsync with v2 `[imports.*]` live imports so the reconciler hot-reloads student edits to `packs/`.

**Pedagogical constraint (from user):** students should be able to edit agent settings and have the reconciler pick up changes automatically. Editing the in-repo `packs/` tree is acceptable as long as hot-reload works — v2 live imports satisfy this with a single source of truth.

**Reconciler behavior (verified against `~/temp/gascity` main):** the reconciler hot-reloads pack content without `gc service restart`. Mechanism:
- `cmd/gc/controller.go:259-299` — `fsnotify` watches config dirs; file changes set a dirty flag after a 200ms debounce.
- `cmd/gc/city_runtime.go:414-416` — each patrol tick (default `patrol_interval = "30s"`) checks the dirty flag and, if set, calls `reloadConfigTraced` → `config.LoadWithIncludes` + `config.ExpandPacks`.
- `internal/config/pack.go:84` — `loadPackWithCache` re-reads `pack.toml` on dirty reloads. `[imports.*]` with `source = "<path>"` are re-resolved on each cycle.
- `cmd/gc/prompt.go:50-100` — `renderPrompt` runs on-demand per session; the rendered prompt is cached in bead metadata until the session wakes. Prompt edits are visible to new sessions immediately and to existing sessions on their next wake. `gc poke` forces an earlier tick.

Net: live imports from the in-repo `packs/` tree deliver the promised hot-reload. Only pitfall to document: a long-lived session won't re-render its prompt until it wakes.

## Full inventory (what moves)

### Pack trees

**Canonical `packs/` — 11 items:**
| Pack | Has agent? | Notes |
|---|---|---|
| `architect` | yes | 2 commands, 1 doctor, 1 formula, 1 order, overlay |
| `planner` | yes | 3 commands (incl. `tracker-sync`), 1 doctor, 1 formula, 1 order, overlay, tracker-to-beads skill |
| `designer` | yes | same shape as architect |
| `builder` | yes | same shape |
| `reviewer` | yes | same shape |
| `validator` | yes | same shape |
| `release-gate` | yes | same shape |
| `improver` | yes | same shape |
| `workshop` | **no agent** | 7 doctor checks, 3 commands, 4 orders (already flat at `orders/<name>/order.toml`), no `[[agent]]` block |
| `fired-up-pizza` | **no** (composition) | `includes = [../planner, ../architect, ../designer, ../builder, ../reviewer, ../release-gate]` + 1 doctor |
| `all` | **no** (composition) | `includes = [../architect, ../planner, ../designer, ../validator, ../builder, ../reviewer, ../release-gate, ../improver]` |

**Workshop duplicates `activites/workshops/W2/gascity/step_0/packs/` — 9 items:** `architect`, `builder`, `designer`, `improver`, `planner`, `reviewer`, `validator`, `deployer` (stub, no agent), `all`

**Lab duplicates `activites/labs/L2/gascity/step_0/packs/` — 3 items:** `architect`, `planner`, `all`

(W1/W3/W4/L1/L3/L4/C1 have README placeholders only under `activites/` and `activities/` — no packs yet, nothing to migrate.)

### City files (6 total)

| File | Current shape | Migration |
|---|---|---|
| `/city.toml` | `[workspace]` + `[[rigs]]` with **hardcoded `/Users/david_miura_actual_ai/…` path** | Split to root `pack.toml` + `city.toml`; strip hardcoded path |
| `/packs/city.toml` | `[workspace]` + commented rig template | Split; imports point at sibling packs |
| `/prerequisites/city.toml` | `[workspace]` + active `[[rigs]]` | Split; imports point at `../packs` |
| `/my-factory/city.toml` | `[workspace]` + empty `includes = []` (student workspace) | Split; `pack.toml` starts with no imports — students add them per session |
| `/activites/workshops/W2/gascity/step_0/packs/city.toml` | `[workspace]` + `[[rigs]]` | Split; imports point at local `./` packs |
| `/activites/labs/L2/gascity/step_0/packs/city.toml` | `[workspace]` + `[[rigs]]` | Split; imports point at local `./` packs |

### Formulas (17) and orders (21)

All formulas live at `<pack>/formulas/<name>.formula.toml`. All orders live at either `<pack>/formulas/orders/<name>/order.toml` (17 cases) or `<pack>/orders/<name>/order.toml` (4 cases, `packs/workshop/`).

- Formulas: **rename** `*.formula.toml` → `*.toml` in place, and move any nested single-file subdirs to top-level `formulas/<name>.toml`.
- Orders: **flatten** from `<pack>/formulas/orders/<name>/order.toml` → `<pack>/orders/<name>.toml`. The workshop pack's `orders/<name>/order.toml` → `orders/<name>.toml`.

### Tutorial / docs

| File | Change |
|---|---|
| `/prerequisites/quickstart.md` | Major rewrite (see §Quickstart) |
| `/installation.md` | Review; update any 0.14.1 refs or packs-install instructions |
| `/my-factory/README.md` | Update per-session wiring instructions (imports block, not `includes = [...]`) |
| `/README.md` (top-level) | Scan for schema=1 / rsync / `packs/actual/` language; update |
| `/packs/README.md` | Philosophy still accurate; update snippets if any reference old syntax |
| `/curriculum/{workshops,labs,capstone}/*/README.md` + `PROMPT.md` | Scan for per-session pack wiring instructions; rewrite any `includes = [...]` examples to `[imports.X] source = "..."` |
| `/activities/README.md` + per-session READMEs | Same scan; these are placeholders today so likely minimal |

## Pack migration template

Applied to every **agent-bearing leaf pack** (architect, planner, designer, builder, reviewer, validator, release-gate, improver — × all three trees where the pack exists).

**Before — `packs/architect/pack.toml:14-48`:**
```toml
[pack]
name = "actual-architect"
schema = 1

[[doctor]]
name = "check-architect"
script = "doctor/check-architect.sh"

[[commands]]
name = "status"
script = "commands/status.sh"

[formulas]
dir = "formulas"

[[agent]]
name = "architect"
scope = "rig"
wake_mode = "fresh"
work_dir = ".gc/agents/{{.Rig}}/architect"
prompt_template = "prompts/architect.md.tmpl"
overlay_dir = "overlays/default"
idle_timeout = "2h"
# …
```

**After — directory layout:**
```
architect/
├── pack.toml                       # [pack] name only
├── README.md
├── agents/
│   └── architect/
│       ├── agent.toml              # scope, wake_mode, work_dir, idle_timeout, nudge, limits
│       ├── prompt.template.md      # moved from prompts/architect.md.tmpl
│       └── overlay/                # moved from overlays/default/
│           └── .claude/…           # unchanged contents
├── commands/
│   ├── status/run.sh               # moved from commands/status.sh
│   └── rules/run.sh                # moved from commands/rules.sh
├── doctor/
│   └── check-architect/run.sh      # moved from doctor/check-architect.sh
├── formulas/
│   └── mol-architect-review.toml   # flat; was formulas/mol-architect-review.formula.toml
├── orders/
│   └── architect-guardrail-check.toml  # flat; was formulas/orders/architect-guardrail-check/order.toml
└── assets/
    └── sync-actual-skill.sh        # moved from scripts/
```

**After — `pack.toml`:**
```toml
[pack]
name = "actual-architect"
```

**After — `agents/architect/agent.toml`:**
```toml
scope = "rig"
wake_mode = "fresh"
work_dir = ".gc/agents/{{.Rig}}/architect"
nudge = "Run 'gc prime', then check bd ready --label=needs-architecture for work."
idle_timeout = "2h"
min_active_sessions = 0
max_active_sessions = 1
```

**Discard stale `prompts/<name>.md`** (not `.tmpl`) files — they're v1 artifacts that aren't wired to the agent. The agent reads the template.

### Non-agent pack migrations

**`packs/workshop/`** — no `[[agent]]`; pack.toml has 7 `[[doctor]]` + 3 `[[commands]]` + `[formulas] dir = "formulas"`. Migration:
- Drop `schema`, `[formulas]`, all `[[doctor]]`/`[[commands]]` blocks from `pack.toml`.
- Restructure: `commands/<name>.sh` → `commands/<name>/run.sh`; `doctor/<name>.sh` → `doctor/<name>/run.sh`.
- Flatten orders: `orders/sync-github/order.toml` → `orders/sync-github.toml` (× 4).
- Keep `env.example`, `README.md`, `overlays/` in place.

**`packs/fired-up-pizza/`** — composition + 1 doctor. Migration:
```toml
[pack]
name = "fired-up-pizza"
description = "..."

[imports.planner]       source = "../planner"
[imports.architect]     source = "../architect"
[imports.designer]      source = "../designer"
[imports.builder]       source = "../builder"
[imports.reviewer]      source = "../reviewer"
[imports.release-gate]  source = "../release-gate"
```
Plus `doctor/check-project/run.sh` (moved from `doctor/check-project.sh`).

**`packs/all/`** — composition only. Same `includes` → `[imports.*]` conversion; 8 imports.

**`activites/workshops/W2/.../packs/deployer/`** — stub pack. No agent today, just a prompt. Either (a) migrate to a v2 agent with `agents/deployer/prompt.template.md`, or (b) leave as a docs-only pack (`pack.toml` with just `[pack] name = ...`). Recommend (b) until W2 curriculum actually wires it up.

## city.toml / pack.toml split template

Applied to each of the 6 city files.

**Before — `prerequisites/city.toml:14-32`:**
```toml
[workspace]
name = "base-gc-factory"
provider = "claude"
start_command = "~/.nvm/versions/node/v22.19.0/bin/claude"
includes = ["packs/actual/all"]

[[rigs]]
name = "base-project"
path = "~/Projects/factory/baseline/base-project"
includes = ["packs/actual/all"]

[session]
startup_timeout = "3m"

[daemon]
# …
```

**After — new `prerequisites/pack.toml`:**
```toml
[pack]
name = "base-gc-factory"

[imports.actual]
source = "../packs"
```

**After — slimmed `prerequisites/city.toml`:**
```toml
[workspace]
name = "base-gc-factory"
provider = "claude"
start_command = "~/.nvm/versions/node/v22.19.0/bin/claude"

[[rigs]]
name = "base-project"
# path field removed; prefix assigned at `gc rig add` time

[rigs.imports.actual]
source = "../packs"

[session]
startup_timeout = "3m"

[daemon]
patrol_interval = "30s"
max_restarts = 5
restart_window = "1h"
shutdown_timeout = "5s"
```

**Per-city specifics:**
- `/city.toml` — strip the hardcoded `/Users/david_miura_actual_ai/…` path; parameterize or delete the rig block.
- `/my-factory/city.toml` → new `/my-factory/pack.toml` with no imports (students add per session per curriculum); city.toml keeps the commented rig template.
- `/activites/workshops/W2/.../packs/city.toml` → sibling `pack.toml` with `[imports.actual] source = "."` (or restructure so the city.toml lives one level up and imports `./packs`, the more conventional layout). Same pattern for L2.

## Quickstart rewrite (`prerequisites/quickstart.md`)

Line-keyed rewrite:

- **Lines 17-23 (0.14.1 pin block):** delete. v2 requires 0.15+.
- **Lines 25-32 (Latest):** keep, add note that `gc version` must report ≥ 0.15.0 for v2.
- **Lines 44-57 (`gc init`):** keep `3. custom`.
- **Lines 61-69 (Configure Factory):**
  - **Drop the rsync line (64) entirely.**
  - Line 63: copy both `prerequisites/pack.toml` and `prerequisites/city.toml` into the factory.
  - Keep `gc service restart` / `gc status` / `gc doctor --fix`. (The migration guide positions `gc doctor --fix` as the v2 safety net — useful even when packs are hand-migrated.)
- **Lines 71-76 (`gc rig add`):** unchanged.
- **Lines 78-82 (`gc register`):** unchanged.
- **Lines 84-89 (`bd config` convoy patch):** unchanged.
- **Lines 91-115 (restart / dashboard / sling):** unchanged.
- **Lines 117-120 (References):** add migration guide link.

**New section:** explain that packs live in the repo's `packs/` tree (no copy), and student edits hot-reload via fsnotify + 30s patrol — with one caveat: prompt edits apply to new sessions immediately and to running sessions on next wake. `gc poke` forces an immediate reconcile tick.

## Migration order

Per pack tree, in this order, to keep intermediate state valid:

1. Migrate leaf packs (no cross-pack deps): 8 agent packs + `workshop` + `fired-up-pizza`.
2. Migrate composition packs (`all`, `fired-up-pizza` imports, W2/L2 `all`).
3. Split city.tomls → pack.toml + city.toml at each city root.
4. Run `gc doctor` in a scratch factory to validate v2 schema.
5. Rewrite `prerequisites/quickstart.md`, `my-factory/README.md`, and any other docs referencing old syntax.
6. Scan for stale references: grep for `schema = 1`, `prompt_template`, `overlay_dir`, `formulas/orders/`, `includes = [`, `rsync`, `packs/actual/` — fix all hits (except intentional "what changed" callouts).

## Out of scope (flag, don't fix)

- **`activites/` typo vs `activities/` correct spelling** — two parallel trees. Rolling in a rename risks git churn on top of the schema migration. Recommend a separate PR.
- **`reference-project/fired-up-pizza/`** — sample project, not a pack. No .toml files, no migration needed.
- **Deferred gascity features** the migration guide notes as not yet in wave (`defaults.rig.imports` #360, agent-local `append_fragments` #671, etc.). Don't design around them; use what's live in 0.15.x.

## Critical files

All pack.toml paths (23 total):
```
packs/{architect,builder,designer,improver,planner,reviewer,validator,release-gate,workshop,fired-up-pizza,all}/pack.toml
activites/workshops/W2/gascity/step_0/packs/{architect,builder,designer,improver,planner,reviewer,validator,deployer,all}/pack.toml
activites/labs/L2/gascity/step_0/packs/{architect,planner,all}/pack.toml
```

All city.toml paths (6):
```
city.toml
packs/city.toml
prerequisites/city.toml
my-factory/city.toml
activites/workshops/W2/gascity/step_0/packs/city.toml
activites/labs/L2/gascity/step_0/packs/city.toml
```

Docs to rewrite:
```
prerequisites/quickstart.md           (major)
installation.md                       (minor — strip 0.14.1 refs if present)
my-factory/README.md                  (update per-session wiring examples)
README.md                             (scan)
packs/README.md                       (scan)
curriculum/**/README.md, **/PROMPT.md (scan)
activities/**/README.md               (scan; placeholders)
```

## Verification

End-to-end smoke test of the migrated repo on a clean factory:

1. **Static validation**
   - `gc doctor` on each migrated pack tree — zero v2 schema errors.
   - `gc doctor --fix` as a no-op confirmation (we migrated by hand).
   - Grep the repo for `schema = 1`, `prompt_template`, `overlay_dir`, `formulas/orders/`, `includes = [`, `rsync`, `packs/actual/` — all gone or only in intentional historical context.

2. **New quickstart on a throwaway factory**
   - Follow the rewritten `prerequisites/quickstart.md` on `~/tmp/sfi-v2-smoke`.
   - `gc status`, `gc register`, `gc start` succeed without errors.
   - `gc sling base-gc-factory "Create a script that prints hello world"` fires the architect → planner → … flow (label-based handoff preserved).

3. **Hot-reload (the core pedagogical promise)**
   - With factory running, edit `packs/architect/pack.toml` in the repo. Confirm fsnotify → dirty flag → reload within ~30s, no `gc service restart`. `gc poke` forces immediate tick.
   - Edit `packs/architect/agents/architect/prompt.template.md`. Confirm a newly-woken session renders with the edit; an already-active session keeps its cached prompt until next wake (per `cmd/gc/prompt.go:50-100`). Document this in the quickstart.

4. **Workshop/lab parity**
   - Repeat smoke test against W2 packs as a standalone city.
   - Repeat against L2 packs.
   - Confirm `packs/fired-up-pizza` + `reference-project/fired-up-pizza/` still integrate as documented.

5. **Dashboard sanity**
   - `gc dashboard serve` reaches `http://localhost:8080`.
   - All rigs/agents show as expected.

If any step fails, capture the error and decide: v2 migration bug (fix in repo) vs gascity 0.15.x gap (file upstream, as with #760 today).
