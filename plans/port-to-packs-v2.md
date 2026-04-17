# Port repo to Pack v2

Committed migration plan. All design decisions resolved; execution proceeds per-pack in lockstep with docs (Principle 3).

## Context

Gas City 0.15.x introduces **Pack v2** (pack-vnext). Migration guide: https://docs.gascityhall.com/guides/migrating-to-pack-vnext.

This is a **format-only migration**. The repo shape stays: agent-per-pack under `packs/`, composition packs (`all`, `fired-up-pizza`), workshop integrations pack, checkpoint trees under `activites/workshops/Wn/gascity/step_X/packs/`, the `my-factory/` workspace. What changes is the TOML schema and on-disk layout.

Pedagogical promise (with documented caveats — see §Hot-reload expectations): students edit files in their cloned repo; the reconciler's fsnotify + 30s patrol tick reloads `pack.toml` at pack-top depth. `gc restart` is the recovery path for nested agent-file edits.

## Principles

These govern judgment calls during execution. When the plan is ambiguous, these apply.

1. **Shape preservation is the default.** Keep the existing repo structure — per-agent packs, composition packs (`all`, `fired-up-pizza`), checkpoint snapshots under `activites/`, `my-factory/`, `curriculum/`. Fix only what would make v2 non-functional (David's hardcoded path in `/city.toml`, `overlays/` → `overlay/` singular). Cosmetic cleanup like the `activites/` typo rename ships as a separate PR after this one.

2. **Runtime gaps get filed, commented, and worked around — never blocked on.** For every Gas City 0.15.x gap that affects workshop content: file an issue at `gastownhall/gascity` with a `workshop:` title prefix; at the workaround site in this repo, leave a comment linking the issue, listing the affected workshop content, what the upstream fix would unblock, and the workaround in use. Implement the workaround. Goal: 100% working workshop content against packs v2 as it ships today.

3. **Docs and packs migrate in lockstep, per pack.** A commit that moves `packs/architect/` to v2 format also updates every curriculum and activities doc that references it. No intermediate state where a README tells students to edit a path the pack has already moved.

4. **Checkpoints migrate schema-only, with stale-path fixes allowed.** `activites/workshops/Wn/.../packs/` and `activites/labs/Ln/.../packs/` get (a) `pack.toml` schema=1 → 2, (b) directory layout changes, (c) runtime-path updates inside formulas/docs to match renamed assets. **No prompt or behavior content changes.** Prompt/workflow edits ship as separate curriculum PRs.

5. **Spike before committing load-bearing assumptions.** Done for this migration — results captured in §Spike results.

6. **Hard cutover to Gas City 0.15+** except where an unavoidable gap (ledger entry G1-G10) forces a v1-shape workaround with a filed upstream issue. `installation.md` requires ≥ 0.15.0; `schema = 2` intentionally breaks on 0.14.x.

7. **"Done" means student-usable, not just schema-passing.** `gc doctor` clean at every city root (except the two enumerated deprecation warnings) is necessary but not sufficient. Migration lands only after a fresh clone + rewritten quickstart + W1 dry run on a clean machine produces a working factory with label handoffs firing.

8. **Claims about Gas City runtime behavior cite file + section name.** Source citations use file path + function or heading name — stable across refactors. Line numbers only when needed to disambiguate inside a large function.

## Known Gas City gaps — filed upstream

Ten gaps block the ideal v2 migration; each has a workaround and an upstream issue. Every workaround site in this repo gets a comment linking the issue.

| # | Gap (short) | Upstream issue | Workaround |
|---|---|---|---|
| G1/G2/G3 | Pack-root `skills/` + per-agent `agents/<n>/skills/` + `[agent_defaults] skills/mcp` all discovered but not session-staged | Comment on [#669](https://github.com/gastownhall/gascity/issues/669) | Per-agent `overlay/.claude/skills/<skill>/` (v1-style duplication across 8 agents) |
| G4a | `WatchDirs` ignores v2 `[imports.*]` — only watches v1 `Includes` | [#779](https://github.com/gastownhall/gascity/issues/779) | Keep v1 `default_rig_includes` in `[workspace]`; accept deprecation warning |
| G4b | fsnotify watches are non-recursive — nested agent/prompt edits don't trigger reload | [#780](https://github.com/gastownhall/gascity/issues/780) | Document `gc restart` for nested edits |
| G5 | Three-way skew on v2 default-rig-imports target shape (docs/doctor/migrate disagree; loader honors none) | [#781](https://github.com/gastownhall/gascity/issues/781) | Use v1 `default_rig_includes`; accept `v2-default-rig-import-format` warning |
| G6 | `gc rig add --include` is single-string | [#782](https://github.com/gastownhall/gascity/issues/782) | Use `default_rig_includes` for one-set-per-factory; hand-edit `[rigs.imports.X]` for per-rig variation |
| G7 | `gc register --name` mutates committed city.toml | Comment on [#602](https://github.com/gastownhall/gascity/issues/602) | `city.toml`/`pack.toml` kept gitignored; students copy from `.template` variants |
| G8 | `v2-workspace-name` deprecation noise | Comment on [#600](https://github.com/gastownhall/gascity/issues/600) | Document expected warning in `my-factory/README.md` |
| G10 | `pack.toml` loader lacks `CheckUndecodedKeys` — unknown fields silent | [#783](https://github.com/gastownhall/gascity/issues/783) | Rely on template-match review for typo catching |
| G-doc1 | Migration guide says `overlays/` (plural) but loader reads `overlay/` | [#784](https://github.com/gastownhall/gascity/issues/784) | Use `overlay/` singular everywhere |
| G-env | No `PACK_DIR`/`GC_PACK_DIR` in agent session shells | [#785](https://github.com/gastownhall/gascity/issues/785) | Use pack commands (`gc <binding> <cmd>`) instead of path-relative helper invocation |
| G-cmd | Rig-imported packs don't expose commands | [#786](https://github.com/gastownhall/gascity/issues/786) | Dual-import `packs/all` at workspace scope (for commands) AND via `default_rig_includes` (for agents) |
| G-reload | No user-facing `gc reload`/`gc poke` | [#787](https://github.com/gastownhall/gascity/issues/787) | Document `gc restart` as the only config-reload path |
| G-tool1 | `gc doctor --fix` / `gc import migrate` emit shapes loader doesn't honor | [#788](https://github.com/gastownhall/gascity/issues/788) | **Never run** `gc doctor --fix` or `gc import migrate` for default-rig-imports |
| G-schema1 | `[[rigs]].path` schema-required but migration guide says new writes shouldn't persist it | [#789](https://github.com/gastownhall/gascity/issues/789) | Ship no `[[rigs]]` blocks; students run `gc rig add` which appends (to gitignored copy) |

## Spike results (summary)

All Step-0 spikes completed and incorporated into the design.

- **S1** `default_rig_includes` auto-apply on schema=2: **works**. `gc rig add <path>` stamps `rig.Includes` from `[workspace] default_rig_includes`. Rig-scope agents materialize.
- **S2** `gc register --name` mutates committed city.toml: **confirmed**. Drives the gitignored-copy workaround (M4).
- **S3** `gc rig add` appends `[[rigs]]` block with auto-populated includes: **confirmed**. Accumulates student-specific state in city.toml — acceptable in a gitignored copy.
- **S4** `gc doctor` warnings on a minimal v2 city: two known warnings (`v2-default-rig-import-format` G5, `v2-workspace-name` G8) plus upstream-fixed-on-main system-pack noise.
- **S5** `[pack] description` silently accepted: **confirmed**. `CheckUndecodedKeys` isn't called on pack.toml load (G10). Earlier "warns at load" claim was wrong.
- **S6** `$GC_CITY_PATH` resolution: **points to directory containing city.toml**, not repo root. Forces topology-aware script paths — drives us to pack commands instead.
- **S7** `gc sling` target must be agent-qualified (`rig/agent`): **confirmed**. Smoke test uses `bd create … --label` instead.
- **S8** `gc poke`: **doesn't exist** as top-level command. Only hidden `gc convoy poke` exists and doesn't set config-dirty.
- **S9** System-pack deprecation warnings: **0.15.0 release skew**, fixed on `main` (`embed_builtin_packs.go § pruneLegacyEmbeddedOrders`). Not filed upstream.
- **S10** `$PACK_DIR`/`$GC_PACK_DIR` in formula step shell: **not available**. Agent session env from `cmd/gc/template_resolve.go § resolveTemplate` uses `CityRuntimeEnvMap` only (G-env). Falsifies "Option D" — drives us to pack commands.

## Committed design

### Topology — `my-factory/` is the city

The factory lives at `<repo>/my-factory/`. Packs at `<repo>/packs/`. This preserves the existing shape (Principle 1 — `my-factory/` is in the canonical directory list) and keeps `$GC_CITY_PATH` stable per city.

```
<repo>/
├── my-factory/
│   ├── pack.toml.template      # committed
│   ├── city.toml.template      # committed
│   ├── pack.toml               # gitignored (student copies from template at setup)
│   ├── city.toml               # gitignored
│   ├── README.md               # student quickstart — absorbs prerequisites/quickstart.md
│   ├── PROJECT_MANIFEST.md     # unchanged
│   └── .gitignore              # ignores pack.toml, city.toml
├── packs/
│   └── {architect,planner,designer,builder,reviewer,validator,release-gate,improver,workshop,fired-up-pizza,all}/
│       └── (v2 format per §Pack migration template)
├── activites/workshops/W2/gascity/step_0/packs/   # checkpoint tree — own city.toml.template + pack.toml.template
├── activites/labs/L2/gascity/step_0/packs/        # ditto
├── curriculum/                                    # curriculum docs — updated in lockstep per Principle 3
├── activities/                                    # (empty placeholders; typo rename deferred)
├── reference-project/fired-up-pizza/              # unchanged, not a pack
├── README.md                                      # updated: repo-level intro
├── installation.md                                # updated: gc ≥ 0.15.0 floor
└── packs/README.md                                # updated: v2 syntax in examples
```

**Deleted:** `/city.toml`, `/packs/city.toml`, `/prerequisites/` (content absorbed into `my-factory/README.md`).

### Root pack.toml + city.toml (`my-factory/`)

**`my-factory/pack.toml.template`** (committed):
```toml
[pack]
name = "my-factory"
schema = 2

# Workspace-scope import — surfaces `gc all wake-downstream` etc. as CLI commands.
# Workaround for #786 (rig-imports don't expose commands): must be paired with
# the default_rig_includes below to also bring in rig-scope agents.
[imports.all]
source = "../packs/all"
```

**`my-factory/city.toml.template`** (committed):
```toml
[workspace]
name = "my-factory"
provider = "claude"
# start_command omitted — rely on claude on PATH.

# Rig-scope default composition. Auto-stamps rig.Includes on every gc rig add (S1).
# Uses v1 shape because:
#   - #779: WatchDirs ignores v2 imports → losing hot-reload is worse than the warning.
#   - #781: v2 target shape unresolved upstream.
# Accept the v2-default-rig-import-format deprecation warning (G5 / #781).
default_rig_includes = ["../packs/all"]

[session]
startup_timeout = "3m"

[daemon]
patrol_interval = "30s"
max_restarts = 5
restart_window = "1h"
shutdown_timeout = "5s"
```

**`my-factory/.gitignore`**:
```
pack.toml
city.toml
```

### Pack migration template (per agent pack)

Applied to every agent-bearing pack in `packs/` and in W2/L2 checkpoint trees.

```
packs/<pack>/
├── pack.toml                      # [pack] name, schema = 2 — no description field (#783)
├── README.md                      # content updates per Principle 3
├── agents/
│   └── <agent>/
│       ├── agent.toml             # scope, wake_mode, work_dir, nudge, idle_timeout, limits
│       ├── prompt.template.md     # mv from prompts/<n>.md.tmpl (or prompt.md for plain markdown)
│       └── overlay/               # SINGULAR per #784
│           └── .claude/
│               ├── settings.json  # mv from overlays/default/.claude/settings.json
│               └── skills/        # per-agent copy (workshop:#669 comment — G1/G2/G3 workaround)
├── commands/
│   └── <cmd>/
│       ├── command.toml           # description — required (gc help depends on it)
│       └── run.sh                 # mv from commands/<cmd>.sh
├── doctor/
│   └── <check>/
│       ├── doctor.toml            # description
│       └── run.sh                 # mv from doctor/<check>.sh
├── formulas/
│   └── <formula>.toml             # renamed from .formula.toml
├── orders/
│   └── <order>.toml               # flattened from formulas/orders/<n>/order.toml
└── assets/
    └── <helper>.sh                # authoring helpers; script body rewritten for new skill paths
```

**`pack.toml` body**:
```toml
[pack]
name = "actual-<pack>"
schema = 2
```

No `[formulas]`, `[[doctor]]`, `[[commands]]`, `[[agent]]`, `description` — all discovered by convention.

**`agent.toml` body** (values verbatim from v1 `[[agent]]` block):
```toml
scope = "rig"
wake_mode = "fresh"
work_dir = ".gc/agents/{{.Rig}}/<agent>"
nudge = "…"
idle_timeout = "2h"
min_active_sessions = 0
max_active_sessions = 1
```

**`command.toml` / `doctor.toml` sidecar body**:
```toml
description = "<from v1 [[commands]].description or [[doctor]].description>"
```

### Composition pack migrations

**`packs/all/pack.toml`**:
```toml
[pack]
name = "actual-factory"
schema = 2

[imports.architect]
source = "../architect"

[imports.planner]
source = "../planner"

[imports.designer]
source = "../designer"

[imports.validator]
source = "../validator"

[imports.builder]
source = "../builder"

[imports.reviewer]
source = "../reviewer"

[imports.release-gate]
source = "../release-gate"

[imports.improver]
source = "../improver"
```

Plus:
- `packs/all/scripts/wake-downstream.sh` → **`packs/all/commands/wake-downstream/run.sh`** (+ sidecar `command.toml`). Turns into a pack command. Formula handoff steps call `gc all wake-downstream &` (G-env / #785 + G-cmd / #786 workaround).

**`packs/fired-up-pizza/pack.toml`**: same shape, 6 imports (planner, architect, designer, builder, reviewer, release-gate). Plus:
- `packs/fired-up-pizza/scripts/import-tickets.sh` → **`packs/fired-up-pizza/commands/import-tickets/run.sh`** + sidecar.
- `[[doctor]] check-project` → `doctor/check-project/` dir + sidecar.

**`packs/workshop/`** (no agent): add `schema = 2`; keep `name`, `version`; drop `description`. Restructure commands/doctor to sidecar dirs. Flatten orders to `orders/<n>.toml`. Rename `overlays/` → `overlay/` (singular per #784); drop the `default/` subdir (loader reads directly under `overlay/`). Overlay content reaches sessions via `PackOverlayDirs` (verified runtime path) because `packs/workshop/` will be imported at workspace scope too (see §Workshop pack inclusion below).

### Workshop pack inclusion

To surface workshop pack's doctor/commands AND have its MCP overlay reach sessions, `my-factory/pack.toml.template` imports it at workspace scope alongside `packs/all`:

```toml
# my-factory/pack.toml.template (augmented)
[pack]
name = "my-factory"
schema = 2

[imports.all]
source = "../packs/all"

[imports.workshop]
source = "../packs/workshop"
```

### Formula handoff rewrite

Every formula file that currently contains:
```bash
sh packs/actual/all/scripts/wake-downstream.sh &
```

becomes:
```bash
gc all wake-downstream &
```

Comment at the callsite:
```markdown
# Formula handoff uses the pack-command shape (gc <binding> <cmd>) because:
#   - Gas City 0.15.x doesn't expose PACK_DIR in agent session shells (workshop:#785).
#   - Topology-agnostic — works from my-factory/ AND from any W2/L2 checkpoint city
#     that imports packs/all at workspace scope.
```

Same pattern for `curriculum/labs/L2/PROMPT.md`'s `packs/fired-up-pizza/scripts/import-tickets.sh` → `gc fired-up-pizza import-tickets …`.

`rg -l 'wake-downstream.sh' packs/ activites/ curriculum/` enumerates all callsites.

### Checkpoint trees

Each checkpoint city (W2, L2) gets its own `pack.toml.template` + `city.toml.template` + gitignored copies, pointing at its local `./packs/all`:

```toml
# activites/workshops/W2/gascity/step_0/packs/pack.toml.template
[pack]
name = "w2-step-0-factory"
schema = 2

[imports.all]
source = "./all"
```

```toml
# activites/workshops/W2/gascity/step_0/packs/city.toml.template
[workspace]
name = "w2-step-0-factory"
provider = "claude"
default_rig_includes = ["./all"]
# … session, daemon
```

Each checkpoint pack gets the Pack migration template. **W2 deployer migrates as a real agent** with plain `prompt.md` (no templating — `[[agent]]` block in current pack.toml confirms `prompt_template = "prompts/deployer.md"` and grep shows no `{{` inside it).

Principle 4 governs: schema + layout + stale-path fixes (the `gc all wake-downstream` rewrite) are allowed. No prompt or behavior content changes.

Student tests a checkpoint:
```bash
cd activites/workshops/W2/gascity/step_0/packs/
cp city.toml.template city.toml
cp pack.toml.template pack.toml
gc register --name w2-check .
gc rig add ~/Projects/test-rig
gc start
```

### Multi-clone handling

`my-factory/city.toml` and `my-factory/pack.toml` are gitignored. Students copy from `.template` variants at setup. `gc register --name` and `gc rig add` mutate the gitignored copies — no dirty git tree, no merge conflicts on curriculum pulls.

Workaround for #602 (register mutates file) and #600 (workspace.name retirement). Setup step lives in `my-factory/README.md`:

```bash
cp my-factory/city.toml.template my-factory/city.toml
cp my-factory/pack.toml.template my-factory/pack.toml
# Optional: edit my-factory/city.toml workspace.name for cohort uniqueness.
cd my-factory
gc register .                            # OR gc register --name <cohort-alice> .
gc rig add ~/Projects/your-project
bd config set types.custom "convoy"
(cd ~/Projects/your-project && bd config set types.custom "convoy")
gc restart
gc status
gc dashboard serve                       # http://localhost:8080

bd create --title "Hello world script" --label needs-architecture
# Architect wakes on the next patrol tick; handoff fires via gc all wake-downstream &
```

### Hot-reload expectations — documented in `my-factory/README.md`

| Edit | Behavior |
|---|---|
| `packs/<p>/pack.toml` | Reloads within ~30s (watched via `rig.Includes` populated by `default_rig_includes`). |
| `packs/<p>/agents/<n>/agent.toml` | Does NOT reload — `gc restart` required (#780). |
| `packs/<p>/agents/<n>/prompt.template.md` | Config not reloaded. Newly-woken sessions render edit; active sessions keep cached prompt until wake. |
| `packs/<p>/formulas/<f>.toml` | Does NOT reload (#780). |
| `packs/<p>/commands/<c>/run.sh` | Does NOT reload (#780). |
| `my-factory/city.toml` | Reloads within ~30s (city root IS watched). |

## Full inventory

Regenerate counts with `find` / `rg` before execution; hand-written numbers have been wrong in earlier drafts.

### Pack trees (23 `pack.toml` files total)

**Canonical `packs/` — 11 packs:**
- `architect`, `builder`, `planner` (each with `scripts/sync-actual-skill.sh` + `overlays/default/.claude/skills/actual/`)
- `designer`, `reviewer`, `validator`, `release-gate`, `improver` (verify shape per-pack; don't assume "same as architect")
- `workshop` (no agent; 7 doctor, 3 commands, 4 orders, critical MCP overlay)
- `fired-up-pizza` (composition + 1 doctor + `scripts/import-tickets.sh`)
- `all` (composition only + `scripts/wake-downstream.sh`)

**Checkpoint `activites/workshops/W2/gascity/step_0/packs/` — 9 packs:** architect, builder, designer, improver, planner, reviewer, validator, deployer (real agent), all + local `city.toml`.

**Checkpoint `activites/labs/L2/gascity/step_0/packs/` — 3 packs:** architect, planner, all + local `city.toml`.

(W1/W3/W4, L1/L3/L4, C1 have README placeholders only.)

### Formulas and orders

Per-pack regeneration (`find packs -name '*.formula.toml'` + `find packs -path '*/orders/*/order.toml'`). Formulas rename `<n>.formula.toml` → `<n>.toml`. Orders flatten `formulas/orders/<n>/order.toml` → `orders/<n>.toml`. Workshop pack's `orders/<n>/order.toml` → `orders/<n>.toml`.

### Helper scripts (move to pack commands)

- `packs/all/scripts/wake-downstream.sh` → `packs/all/commands/wake-downstream/run.sh` + sidecar.
- `packs/fired-up-pizza/scripts/import-tickets.sh` → `packs/fired-up-pizza/commands/import-tickets/run.sh` + sidecar.
- `packs/{architect,builder,planner}/scripts/sync-actual-skill.sh` (three packs only) → `<pack>/assets/sync-actual-skill.sh`. Authoring helper, not called at runtime. Script body also edited to point at `agents/<n>/overlay/.claude/skills/actual/` (new path).

### Docs

| File | Change |
|---|---|
| `my-factory/README.md` | Major rewrite — absorbs `prerequisites/quickstart.md`, documents hot-reload expectations and enumerated `gc doctor` warnings |
| `README.md` (top-level) | Update `includes = [...]` → `[imports.X]` syntax examples; remove rsync references |
| `installation.md` | Add `gc version ≥ 0.15.0` floor |
| `packs/README.md` | Update pack syntax examples |
| `packs/*/README.md` | Per-pack updates where content references old paths |
| `curriculum/**/{README.md,PROMPT.md}` | Grep-driven rewrite (see §Curriculum doc rewrite) |
| `activities/**/README.md` | Same scan — has real docs (W4, C1) |
| `activites/**/README.md` | Same — typo tree has real docs |
| `reference-project/fired-up-pizza/README.md` | Update references to old script paths |

### City files

- **Delete:** `/city.toml`, `/packs/city.toml`, `/prerequisites/city.toml`, `/prerequisites/quickstart.md` (content → `my-factory/README.md`), `/prerequisites/` (entire dir if empty).
- **Create:** `my-factory/{pack.toml,city.toml}.template` + `my-factory/.gitignore`.
- **Create:** `activites/workshops/W2/gascity/step_0/packs/{pack.toml,city.toml}.template` + `.gitignore`.
- **Create:** `activites/labs/L2/gascity/step_0/packs/{pack.toml,city.toml}.template` + `.gitignore`.
- **Retire:** `my-factory/city.toml` (current, committed) → replaced by gitignored copy derived from template.

## Curriculum doc rewrite

Grep-driven, heading-anchored:

```
rg 'packs/(architect|planner|designer|builder|reviewer|validator|release-gate|improver|all|fired-up-pizza)/' \
   curriculum/ activities/ activites/ my-factory/ prerequisites/ reference-project/ packs/
rg 'includes = \[' curriculum/ activities/ activites/ my-factory/ prerequisites/
rg 'prompt_template|overlay_dir|schema = 1|formulas/orders/|overlays/default' .
rg 'prompts/.*\.md(\.tmpl)?|commands/.*\.sh|scripts/(sync-actual-skill|wake-downstream|import-tickets)' .
```

Rewrite rules:
- `packs/<agent>/prompts/<agent>.md.tmpl` → `packs/<agent>/agents/<n>/prompt.template.md` (or `prompt.md` if plain markdown).
- `packs/<agent>/commands/<cmd>.sh` → `packs/<agent>/commands/<cmd>/run.sh`.
- `packs/<agent>/overlays/default/` → `packs/<agent>/agents/<n>/overlay/`.
- `packs/actual/all/scripts/wake-downstream.sh` → `gc all wake-downstream`.
- `packs/fired-up-pizza/scripts/import-tickets.sh` → `gc fired-up-pizza import-tickets`.
- `includes = [...]` → appropriate `[imports.X]` or `default_rig_includes` per context.

**Curriculum teaches 6 agents, factory has 8:** `curriculum/README.md` and `capstone/C1/README.md` describe a 6-agent pipeline (Planner, Architect, Designer, Coder, Reviewer, Deployer) matching `fired-up-pizza`'s composition. Validator and Improver exist in the factory but have no lessons — document this in README; don't expand curriculum here.

**"8-agent pipeline for label-driven work" → "7 label-driven agents plus 1 periodic improver"** — Improver is cooldown-based, not label-driven.

## Migration order

1. **Architect pack slice:** migrate `packs/architect/` to v2; update every curriculum/activities doc referencing it; `gc doctor` passes. Single commit.
2. **Planner pack slice.**
3. **Designer, Builder, Reviewer, Validator, Release-gate, Improver pack slices** (each its own commit, in that order).
4. **Workshop pack slice** (no agent; different shape — no `agents/` dir).
5. **Composition pack slices:** `fired-up-pizza`, then `all`. These depend on leaf packs being v2. `all` also migrates `wake-downstream.sh` to pack command; `fired-up-pizza` migrates `import-tickets.sh`.
6. **Top-level cleanup:** delete `/city.toml`, `/packs/city.toml`, `/prerequisites/`. Migrate `/my-factory/` to template + gitignore shape.
7. **W2 checkpoint tree:** per-pack migrations (9 packs) + sibling `pack.toml.template`/`city.toml.template`/`.gitignore`.
8. **L2 checkpoint tree:** same (3 packs).
9. **Top-level docs:** `README.md`, `installation.md`, `my-factory/README.md` (absorbs quickstart), `packs/README.md`.
10. **Principle-2 traceability:** add workaround comments with issue links at every v1-shape / dual-import / deprecation-warning-accepting site.
11. **End-to-end verification** per §Verification.

## Critical files

**23 pack.toml files to rewrite:**
```
packs/{architect,builder,designer,improver,planner,reviewer,validator,release-gate,workshop,fired-up-pizza,all}/pack.toml
activites/workshops/W2/gascity/step_0/packs/{architect,builder,designer,improver,planner,reviewer,validator,deployer,all}/pack.toml
activites/labs/L2/gascity/step_0/packs/{architect,planner,all}/pack.toml
```

**3 city/pack.toml template pairs to create:**
```
my-factory/{city.toml,pack.toml}.template + .gitignore
activites/workshops/W2/gascity/step_0/packs/{city.toml,pack.toml}.template + .gitignore
activites/labs/L2/gascity/step_0/packs/{city.toml,pack.toml}.template + .gitignore
```

**To delete:**
```
/city.toml
/packs/city.toml
/prerequisites/ (entire dir)
my-factory/city.toml (current committed copy — superseded by template + gitignored runtime copy)
```

## Out of scope

- Pinning a specific gascity commit beyond ≥ 0.15.0.
- Remote pack imports (git URLs) — deferred per migration guide.
- Curriculum expansion to Validator/Improver lessons — separate effort.
- `reference-project/fired-up-pizza/` as a pack (it's sample project content; README refs still updated).
- Flat single-pack redesign — blocked by G1-G10; revisit when upstream issues close.
- `activites/` → `activities/` typo rename — separate PR per Principle 1.

## Verification

1. **Static validation**
   - `gc doctor` from `my-factory/` — zero errors; two expected warnings (G5 `v2-default-rig-import-format`, G8 `v2-workspace-name`). Document the expected warnings in `my-factory/README.md`.
   - `gc doctor` from each W2/L2 checkpoint city — same acceptance criteria.
   - `find . -name pack.toml | xargs grep -l 'schema = 1'` returns empty.
   - `rg 'prompt_template|overlay_dir|formulas/orders|packs/actual/|overlays/default|\{\{\.CityRoot\}\}'` returns empty outside intentional historical callouts.
   - `taplo check` (or equivalent) on every new TOML file.

2. **End-to-end smoke test on a fresh clone**
   - Follow `my-factory/README.md` verbatim.
   - `gc register .`, `gc rig add ~/tmp/smoke-project`, `gc restart`, `gc status` all succeed.
   - `bd create --title "Hello world" --label needs-architecture` → architect wakes within patrol tick, handoff chain fires via `gc all wake-downstream &`, planner-intake order triggers.
   - Dashboard at `http://localhost:8080` shows 8 agents × 1 rig.

3. **Hot-reload test** (document what works vs what doesn't)
   - Edit `packs/architect/pack.toml` (touch a comment) → reload within 30s.
   - Edit `packs/architect/agents/architect/agent.toml` → NOT reloaded (#780). Document `gc restart` required.
   - Edit `packs/architect/agents/architect/prompt.template.md` → newly-woken sessions render with edit; active sessions keep cached prompt until wake.

4. **Skills-visibility test**
   - From a running session, confirm `.claude/skills/actual/SKILL.md` is materialized (from per-agent overlay — #669 workaround).
   - `packs/planner/commands/tracker-sync/run.sh` finds tracker-to-beads skill.

5. **Workshop MCP test**
   - Start the factory. Confirm workshop's `overlay/.claude/settings.json` MCP fragments appear in the session's merged `.claude/settings.json`.

6. **Checkpoint test** (scratch dir, non-destructive)
   - `mkdir -p /tmp/w2-check && cp -r activites/workshops/W2/gascity/step_0/packs/* /tmp/w2-check/ && cd /tmp/w2-check && cp city.toml.template city.toml && cp pack.toml.template pack.toml`
   - `gc register --name w2-check .`, `gc rig add`, `gc start` — 9 agents wake.

7. **Multi-clone test**
   - Clone this repo twice. Setup both per `my-factory/README.md`. Both `gc register` without collision (each has its own gitignored `city.toml` with local `workspace.name`).

8. **Regression check vs v1 behavior**
   - Label-based handoff chain fires identically (`needs-architecture` → architect → `needs-plan` → planner → …).
   - Improver runs on cooldown, not label.

If any step fails: update the gap ledger, file upstream with `workshop:` prefix, implement workaround per Principle 2.
