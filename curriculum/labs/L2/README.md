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

Compare the planner prompt to your W1 workflow card:

| Your Workflow Card | Planner Prompt Section |
|-------------------|----------------------|
| Prompt Template | `## Inputs` — what context the agent reads |
| Context Reset Rule | `wake_mode = "fresh"` in agent.toml |
| Iteration Loop | `## Graph Work Process` — the work loop |
| Decision Checkpoint | `## Role` — scope of authority, what to escalate |

Your workflow card described how *you* work with one agent. The planner prompt describes how *the planner agent* works inside a factory. Same structure, different scope.

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

## Observability Commands

These are your windows into a running factory. Practice all six while L2 runs:

| Command | What It Shows |
|---------|---------------|
| `gc events --follow` | Live event stream (agent wakes, step transitions) |
| `gc session list` | Active and recent agent sessions |
| `gc session peek <id>` | Live view of what an agent is doing now |
| `gc graph <bead-id>` | Formula step state graph |
| `bd list` | All beads in the current rig |
| `bd show <id>` | Detailed bead state and metadata |

You will use these throughout L3, L4, and C1.

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

## Part 5: Attach a Real Capability

The planner and architect currently work from project context alone. Ground one of them in a real external system.

### Choose one capability to attach

| Capability | Agent | What It Adds |
|-----------|-------|-------------|
| GitHub MCP | Architect | Read existing code, PRs, issues |
| Linear/Jira MCP | Planner | Pull real tickets as input |
| Context7 MCP | Architect | Up-to-date library docs |
| `actual status` CLI | Planner | Project health data |

### Wire it up

1. Inspect the workshop pack for examples:

       cat packs/workshop/overlay/.claude/settings.json | head -20

2. Add the MCP to your chosen agent's overlay:

       $EDITOR packs/lessons/L2/agents/planner/overlay/.claude/settings.json

   Add an mcpServers section. Example for GitHub:

       "mcpServers": {
         "github": {
           "type": "http",
           "url": "https://api.githubcopilot.com/mcp/",
           "headers": { "Authorization": "Bearer ${GITHUB_TOKEN}" }
         }
       }

3. Edit the agent's prompt to name the new capability:

       $EDITOR packs/lessons/L2/agents/planner/prompt.template.md

   Add one line to the Inputs section, e.g.: "When available, use the GitHub MCP to check existing code before scoping work."

4. Restart and re-sling:

       export GITHUB_TOKEN=<your-token>  # or whichever credential
       gc restart
       gc sling <rig>/factory.planner "Plan <another feature>" \
         --on mol-feature-intake

5. Compare the two plan artifacts. Did the external tool change the output? Record what you changed in activities/labs/L2/notes.md.

MCPs are the bridge between LLM knowledge and project-specific reality. Without them, agents invent reality. With them, agents check reality.

## Part 6: Record Notes

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
- One prompt edit or MCP addition produced a visible artifact change.
- `activities/labs/L2/notes.md` records the root bead, artifact paths, and config changes.
