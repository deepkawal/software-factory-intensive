# My Factory — Workspace Quickstart

This directory **is** your Gas City factory for the Software Factory Intensive. You register it with the Gas City supervisor, add your project as a rig, and run the agents from here.

Packs live one level up under `../packs/`. Your per-session deliverables land in the sibling `../activities/` tree. The shipped reference project at `../reference-project/fired-up-pizza/` has completed examples of every artifact type the factory produces.

## Files in this folder

| File | Purpose |
|------|---------|
| `pack.toml.template` | Committed template — workspace-scope imports for `packs/all` and `packs/workshop`. Copy to `pack.toml` at setup time. |
| `city.toml.template` | Committed template — workspace / session / daemon config + `default_rig_includes`. Copy to `city.toml` at setup time. |
| `pack.toml` | **Gitignored.** Your local copy. Not mutated by any `gc` command. |
| `city.toml` | **Gitignored.** Your local copy; `gc register --name` persists `workspace.name` here; `gc rig add` appends `[[rigs]]` blocks here. |
| `PROJECT_MANIFEST.md` | Manifest template for your project. Filled in during L1, read by every agent. |
| `README.md` | You are here. |

## Prerequisites

See [`../installation.md`](../installation.md) for the full dependency list. Minimum:

- Gas City **≥ 0.15.0** (`brew install gastownhall/gascity/gascity`)
- Claude Code (or another supported coding agent) on your `$PATH`
- `git`, `tmux`, `jq`, `dolt` (pulled in automatically on macOS)

## Quickstart

### 1. Verify Gas City

```bash
brew update
brew upgrade gascity
gc version        # must report >= 0.15.0
```

### 2. Copy the templates into your local config

```bash
cd my-factory
cp pack.toml.template pack.toml
cp city.toml.template city.toml
```

Both files are gitignored. `gc register --name` persists `workspace.name` to `city.toml`; `gc rig add` appends `[[rigs]]` blocks to `city.toml`. `pack.toml` is not mutated by any `gc` command — it's gitignored so you can edit it locally without dirtying the tree when the curriculum pulls upstream.

**If multiple clones live on the same machine** (e.g., cohort-wide workshops), edit `city.toml`'s `workspace.name` to something cohort-unique (like `my-factory-alice`) before the next step. Gas City's supervisor rejects duplicate effective city names across different paths.

### 3. Register the factory

```bash
gc register .
```

This tells the machine-wide Gas City supervisor that `my-factory/` is a city it should manage. You should see:

```
Registered city 'my-factory' (/…/my-factory)
```

### 4. Add your project repo as a rig

A **rig** is the project repo the factory's agents will operate on.

```bash
gc rig add ~/Projects/your-project
```

`gc rig add` appends a `[[rigs]]` block to your local `city.toml` with `rig.Includes` auto-populated from `default_rig_includes`. The 8 agent packs under `../packs/` will all compose into your rig automatically.

### 5. Fix beads directory permissions

The repo ships a `.beads/` directory at repo root; git can't preserve its recommended `0700` mode across clones, so fresh clones show a `beads-store` warning in `gc doctor` until you fix the permission:

```bash
chmod 700 ../.beads
```

### 6. Set the bd convoy type

Your rig needs a `convoy` bead type configured in its own beads store (created by `gc rig add` in step 4):

```bash
(cd ~/Projects/your-project && bd config set types.custom "convoy")
```

### 7. Start the factory

```bash
gc restart
gc status
gc dashboard serve     # http://localhost:8080
```

`gc status` should show the 8 agent names per rig (architect, planner, designer, builder, reviewer, validator, release-gate, improver). The dashboard gives a live view of which agents are waking, what beads they hold, and their handoff state.

### 8. Kick off your first task

From inside your project directory:

```bash
cd ~/Projects/your-project
bd create --title "Your first feature" --label needs-architecture
# Wait up to 30s for the patrol tick. There is no user-facing force-reload
# command in 0.15.x; `gc restart` is the heavy-handed alternative.
```

The architect picks up the `needs-architecture` bead and wakes. When it closes, its formula handoff step runs `gc all wake-downstream &`, which slings the resulting `needs-plan`-labelled child bead to the planner. The flow is **label-based**, not hardcoded — no master orchestrator, no pipeline DAG in Go.

### Expected `gc doctor` output

A fresh clone reports roughly **33 passed, 12 warnings, 2 failed** before you complete the setup above. `gc doctor` is noisy by design; most of what you see is expected. Here's what each class of output means.

**Two failures, both expected pre-setup:**

```
✗ system-formulas — 1 system formula(s) missing or stale
    hint: run gc doctor --fix to re-materialize
✗ beads-store — store ping failed: … permissions 0755 (recommended: 0700)
```

`system-formulas` clears after `gc doctor --fix` re-materializes built-in system formulas; run it once after setup:

```bash
gc doctor --fix
```

`beads-store` clears after step 5 (`chmod 700 ../.beads`) AND step 7 (`gc start`, which brings up the dolt server `bd` connects to).

**Two deprecation warnings, both intentional** — workarounds for Gas City 0.15.x gaps:

```
⚠ v2-default-rig-import-format — workspace.default_rig_includes is deprecated;
    migrate to [rig_defaults] imports = [...]
    hint: run "gc doctor --fix" to rewrite safe mechanical cases, then rerun "gc doctor"
⚠ v2-workspace-name — workspace.name will move to .gc/ in a future release
```

Tracked upstream: [workshop:#781](https://github.com/gastownhall/gascity/issues/781), comment on [#600](https://github.com/gastownhall/gascity/issues/600).

**Most of the remaining ~10 warnings** report missing integration tokens — `GITHUB_TOKEN`, `LINEAR_API_KEY`, cloud CLIs, observability services. Safe to ignore unless you're wiring up that specific integration.

Any other error is real — investigate or re-read `../installation.md`.

## Editing agents (hot-reload)

You'll edit pack files as the curriculum progresses. What hot-reloads and what doesn't:

| Edit | Behavior |
|------|----------|
| `../packs/<pack>/pack.toml` | Reloads within ~30s (fsnotify + patrol tick). |
| `../packs/<pack>/agents/<n>/agent.toml` | Does **not** reload — run `gc restart`. |
| `../packs/<pack>/agents/<n>/prompt.template.md` | Config not reloaded; new agent sessions render with your edit; a running session keeps its cached rendered prompt until it wakes again. |
| `../packs/<pack>/formulas/<f>.toml` | Does **not** reload — run `gc restart`. |
| `my-factory/city.toml` | Reloads within ~30s (city root is watched). |

Nested-file reload limits are an upstream Gas City 0.15.x fsnotify gap — see [workshop:#780](https://github.com/gastownhall/gascity/issues/780). Until fixed, `gc restart` is the reliable recovery path. (There is no `gc poke` top-level command in 0.15.x; `gc convoy poke` exists but only re-dispatches pending convoy work — it doesn't re-read pack files. See [workshop:#787](https://github.com/gastownhall/gascity/issues/787).)

## The 8 agents (7 label-driven + 1 periodic)

| Agent | Label gate | Pack |
|-------|-----------|------|
| Architect | `needs-architecture` | `../packs/architect` |
| Planner | `needs-plan` | `../packs/planner` |
| Designer | `needs-design` | `../packs/designer` |
| Validator | `needs-tests` | `../packs/validator` |
| Builder (Coder in curriculum) | `ready-to-build` | `../packs/builder` |
| Reviewer | `needs-review` | `../packs/reviewer` |
| Release-Gate (Deployer in curriculum) | `ready-to-ship` | `../packs/release-gate` |
| Improver | cooldown (daily), not label-driven | `../packs/improver` |

The curriculum (workshops W1–W4, labs L1–L4, capstone C1) teaches six of these (Planner, Architect, Designer, Coder, Reviewer, Deployer — matching `../packs/fired-up-pizza`'s composition). Validator and Improver ship in `../packs/all` and are available for self-study.

## Where do my deliverables live?

- **Curriculum outputs** (workflow cards, orchestrator files, feedback-loop notes) → `../activities/<workshop-or-lab>/`
- **Customized agent prompts** → edit `../packs/<agent>/agents/<n>/prompt.template.md` directly (committed edits are fine — each cohort fork has its own git history)
- **Factory-generated artifacts** (work packages, ADRs, design specs, review reports, release gates) → inside your rig (your project repo), under the directories named in `PROJECT_MANIFEST.md`

## Getting un-stuck

Every session is designed to be independent and additive. If you break an agent's prompt:

```bash
git checkout ../packs/<agent>/agents/<n>/prompt.template.md
gc restart   # rebuild sessions with the restored prompt
```

The shipped pack is always green — reverting one agent doesn't affect any other.

## References

- [Gas City migration guide (v1 → v2)](https://docs.gascityhall.com/guides/migrating-to-pack-vnext)
- [Gas City quickstart](https://github.com/gastownhall/gascity/blob/main/docs/getting-started/quickstart.md)
- Reference project: [`../reference-project/fired-up-pizza/`](../reference-project/fired-up-pizza/)
- Upstream workshop issues: [gastownhall/gascity `workshop:` filter](https://github.com/gastownhall/gascity/issues?q=is%3Aissue+in%3Atitle+workshop%3A)
