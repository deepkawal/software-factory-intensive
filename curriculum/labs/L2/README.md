# L2 - Deploy Planner + Architect Agents

> **What you will build:** a two-agent lesson factory. One `gc sling` starts a
> FormulaV2 graph. The graph routes first to the Planner and then to the
> Architect.

| | |
|---|---|
| **Estimated duration** | 60-75 minutes |
| **Type** | LAB |
| **Deliverable** | One plan, one architecture decision, and notes linking them to the formula run |

## Mental Model

L2 uses one self-contained pack:

```text
packs/lessons/L2/
  agents/planner/
  agents/architect/
  formulas/mol-feature-intake.toml
```

The formula is the workflow:

```text
plan -> architecture
```

The city selects the active lesson pack. The project rig keeps the work and
artifacts. That means you keep the same rig across lessons and only change
which lesson factory pack is active.

## Prerequisites

- You have copied `my-factory/pack.toml.template` to `my-factory/pack.toml`.
- You have copied `my-factory/city.toml.template` to `my-factory/city.toml`.
- `my-factory/city.toml` has FormulaV2 enabled:

```toml
[daemon]
formula_v2 = true
```

- Your project rig has already been added with `gc rig add`.

## Part 1: Select L2 As The Active Lesson

Open `my-factory/pack.toml` and set the city-wide active factory import:

```toml
[defaults.rig.imports.factory]
source = "../packs/lessons/L2"
```

This import is city-wide lesson selection. The agents inside the factory pack
are still rig-scoped, so the Planner target is:

```text
<rig>/factory.planner
```

Because your rig already exists, sync that rig to the L2 pack:

```bash
cd my-factory
gc --rig <rig> import add ../packs/lessons/L2 --name factory
```

If the `factory` import already exists from another lesson, replace it:

```bash
gc --rig <rig> import remove factory
gc --rig <rig> import add ../packs/lessons/L2 --name factory
```

Restart and check the factory:

```bash
gc restart
gc doctor
```

## Part 2: Read The Lesson Pack

Open these files before running the lesson:

- `packs/lessons/L2/pack.toml`
- `packs/lessons/L2/formulas/mol-feature-intake.toml`
- `packs/lessons/L2/agents/planner/prompt.template.md`
- `packs/lessons/L2/agents/architect/prompt.template.md`

Confirm three things:

- The formula uses `version = 2` and `contract = "graph.v2"`.
- `plan` routes to `factory.planner`.
- `architecture` depends on `plan` and routes to `factory.architect`.

## Part 3: Run The Formula

From `my-factory`, sling one request to the lesson Planner:

```bash
gc sling <rig>/factory.planner "Plan the loyalty points feature for Fired Up Pizza" --on mol-feature-intake
```

Watch progress:

```bash
gc events --follow
```

When you have the root bead ID, inspect the graph:

```bash
gc graph <root-bead-id>
bd show <root-bead-id>
```

Expected graph:

| Step | Agent | Output |
|---|---|---|
| `plan` | `factory.planner` | `docs/plans/<slug>.md` |
| `architecture` | `factory.architect` | `docs/architecture/<slug>.md` |

## Part 4: Inspect The Artifacts

In your project rig, inspect:

```bash
ls docs/plans
ls docs/architecture
```

The plan should include:

- goal
- user stories
- acceptance criteria
- scope boundary
- architect handoff notes

The architecture artifact should include:

- context
- at least two options
- a decision
- consequences
- risks
- reference back to the plan

## Part 5: Record Notes

Create `activities/labs/L2/notes.md`:

```markdown
# L2 Notes

Root bead:

Plan artifact:

Architecture artifact:

Prompt or config changes:

What I would change before L3:
```

Commit the generated artifacts and your notes.

## Exit Criteria

- `gc graph <root-bead-id>` shows `plan -> architecture`.
- The formula route targets are `factory.planner` and `factory.architect`.
- The project rig contains a plan under `docs/plans/`.
- The project rig contains an architecture artifact under `docs/architecture/`.
- `activities/labs/L2/notes.md` records the root bead and artifact paths.
