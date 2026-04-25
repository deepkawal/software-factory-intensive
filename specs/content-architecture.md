# Content Architecture: Self-Contained Lesson Packs

## Summary

The Software Factory Intensive should teach Gas City through self-contained
PackV2 lesson packs. Each lesson pack is a complete, runnable, inspectable
factory for that lesson, even when that duplicates agents, formulas, prompts,
skills, and support files from earlier lessons.

The primary student path should be:

```text
pick lesson pack -> restart city -> sling one request -> formula routes work
```

The student path should not be:

```text
create labelled bead -> order scans label -> helper command wakes downstream ->
agent prompt polls label -> formula relabels bead -> repeat
```

This spec optimizes for teaching. Shared reusable packs may still exist for
maintainers, references, and future production use, but they should not be the
main runtime surface for lessons.

## Teaching Goals

The content should make these concepts obvious in this order:

1. A pack is the unit of factory definition.
2. A lesson pack contains the factory being taught.
3. A formula is the workflow.
4. Agents execute formula steps.
5. Routing is defined by the formula and pack configuration.
6. Beads are the runtime records of work.
7. Labels are metadata for search, provenance, reporting, and human triage.

The curriculum should minimize CLI surface area until the student has a reason
to learn more. The pack should carry defaults; students should not have to pass
five flags to express a concept the pack already knows.

## Current Problem

The current material optimizes for reusable pack composition, not learning.
The runtime is assembled from reusable leaf packs plus `packs/all`.

That makes one lab difficult to inspect:

- agents are split across separate leaf packs
- formulas live inside those leaf packs
- orders watch stage labels
- formulas create or relabel downstream beads
- `gc all wake-downstream` scans labels and slings work
- activities can override selected packs
- `my-factory` controls which pack graph is active

The visible workflow language becomes labels:

- `needs-architecture`
- `needs-plan`
- `needs-design`
- `needs-tests`
- `ready-to-build`
- `needs-review`
- `ready-to-ship`

Those labels are doing work that formulas can express directly through steps,
dependencies, conditions, fanout, checks, retries, and routing metadata.

## Architecture Decision

Create first-class lesson packs under `packs/lessons/`:

```text
packs/
  lessons/
    W1/
    W2/
    W3/
    W4/
    L1/
    L2/
    L3/
    L4/
    C1/
```

Not every conceptual workshop needs a runtime pack immediately. Runtime-heavy
lessons should move first:

1. `L2`
2. `L3`
3. `L4`
4. `C1`
5. `W3` if coordination remains a runtime exercise

Each lesson pack must be self-contained. It must not import earlier lesson packs
or shared agent leaf packs. If L3 needs planner, architect, designer, and
builder agents, L3 contains its own copies of those definitions.

This duplication is intentional. Students should be able to open one folder and
understand the entire factory they are about to run.

## PackV2 Implementation Facts

PackV2 is convention-based. The pack directory structure is the declaration.
Use standard subdirectories:

```text
pack.toml
agents/
formulas/
orders/
commands/
doctor/
overlay/
skills/
mcp/
template-fragments/
assets/
```

Current implementation details that affect lesson design:

- `agents/<name>/` creates an agent by convention.
- `agents/<name>/prompt.template.md` is the canonical templated prompt name.
- `agents/<name>/overlay/` is the agent-local overlay directory.
- formulas live in top-level `formulas/`.
- new orders live in top-level `orders/<name>.toml`.
- commands live in `commands/<name>/run.sh`.
- doctors live in `doctor/<name>/run.sh`.
- rig imports currently contribute doctors but not pack commands.
- current reliable agent defaults are narrow: `default_sling_formula` and
  `append_fragments`.
- `formula_v2` is still opt-in.

Design implication: core lesson workflow should not depend on pack commands.
Commands are useful convenience tools, but formulas should carry the workflow.

## Lesson Pack Contract

Every runtime lesson pack should satisfy this contract:

- has `pack.toml`
- has `README.md`
- has every agent required for the lesson under `agents/`
- has every formula required for the lesson under `formulas/`
- does not import shared packs
- does not require `packs/all`
- has doctor checks for lesson readiness
- starts from one documented `gc sling` command
- uses labels only as metadata
- uses formulas for workflow structure and stage progression

Example L3 shape:

```text
packs/lessons/L3/
  README.md
  pack.toml
  agents/
    planner/
      agent.toml
      prompt.template.md
      overlay/
    architect/
      agent.toml
      prompt.template.md
      overlay/
    designer/
      agent.toml
      prompt.template.md
      overlay/
    builder/
      agent.toml
      prompt.template.md
      overlay/
  formulas/
    mol-l3-factory.toml
    mol-l3-plan.toml
    mol-l3-design.toml
    mol-l3-build.toml
  doctor/
    lesson-ready/
      doctor.toml
      run.sh
  commands/
    status/
      command.toml
      run.sh
  skills/
  template-fragments/
  examples/
```

## `pack.toml` Shape

Minimal:

```toml
[pack]
name = "sfi-l3"
schema = 2
```

Use `[agent_defaults]` only for fields the runtime applies reliably and that
make student commands simpler:

```toml
[agent_defaults]
default_sling_formula = "mol-l3-factory"
append_fragments = ["graph-worker"]
```

Avoid legacy declarations:

- no `[[agent]]`
- no `[formulas]`
- no `[[commands]]`
- no `[[doctor]]`
- no `pack.includes`

## Agent Shape

Keep each agent's essential configuration local:

```toml
scope = "rig"
wake_mode = "fresh"
max_active_sessions = 1
default_sling_formula = "mol-l3-factory"
nudge = "Run gc prime, then work the assigned formula step."
```

Avoid teaching custom `work_query` and `sling_query` in normal lessons. Default
routing is sufficient for the beginner path. Introduce custom routing only in a
lesson that is explicitly about routing internals.

Prompt guidance should fit graph-first work:

- find assigned or routed work
- read the current bead
- execute exactly the current formula step
- close with outcome metadata
- briefly check for more assigned work
- drain when idle

Do not tell agents to poll `bd ready --label=<stage>` forever.

## Formula-Native Workflow

The long-term curriculum should teach formulas as the workflow language.
Formula graphs should own:

- stage order
- dependencies
- parallelism
- branching
- retries
- checks
- gates
- per-step routing
- dynamic fanout when supported by the installed Gas City version

Formula step descriptions still contain judgment. The formula should not try to
replace the agent's judgment. It should express the workflow structure around
that judgment.

Recommended entry formula:

```toml
formula = "mol-l3-factory"
version = 2
contract = "graph.v2"
description = "Run the L3 factory from feature request to reviewed change."

[[steps]]
id = "plan"
title = "Break the feature into implementation work"
metadata = { "gc.run_target" = "planner" }

[[steps]]
id = "design"
title = "Design the UI and interaction changes"
needs = ["plan"]
metadata = { "gc.run_target" = "designer" }

[[steps]]
id = "build"
title = "Implement the approved design"
needs = ["design"]
metadata = { "gc.run_target" = "builder" }

[[steps]]
id = "review"
title = "Review the implementation"
needs = ["build"]
metadata = { "gc.run_target" = "reviewer" }
```

Use formula features before shell workarounds:

- `needs` for dependencies
- `children` for nested work
- `condition` for optional steps
- `loop` for static repetition
- `check` or `retry` for validation and retry behavior
- `metadata.gc.run_target` for agent routing
- `on_complete` for runtime fanout only after classroom reliability is proven

Avoid this pattern:

```text
builder closes bead
builder adds needs-review label
builder calls gc all wake-downstream
wake-downstream finds needs-review
wake-downstream slings bead to reviewer
reviewer formula runs
```

Prefer:

```text
formula step build completes
formula step review becomes ready because it depends on build
review step is routed to reviewer
review outcome controls the next graph edge
```

## Simplest Student CLI

The pack should capture as much as possible so the student command is short.

Preferred:

```bash
gc sling <rig>/planner "Build user profile editing"
```

This is the target when `default_sling_formula` is configured on the entry
agent.

Acceptable when the lesson needs explicit formula attachment:

```bash
gc sling <rig>/planner "Build user profile editing" --on mol-l3-factory
```

Avoid as the normal student path:

```bash
bd create --title "Build user profile editing" --label needs-plan
gc sling --nudge <rig>/planner <bead-id>
```

That path teaches bead creation, stage labels, and explicit routing before the
student has seen the factory concept.

Introduce `bd` after the first run, when students inspect what Gas City created:

```bash
bd list
bd show <bead-id>
bd dep graph <bead-id>
```

## Lesson Switching

Current compatibility shape:

```toml
[workspace]
default_rig_includes = ["../packs/lessons/L3"]
```

If the lesson exposes optional commands, use a workspace import too:

```toml
[imports.lesson]
source = "../packs/lessons/L3"
```

This dual import is an implementation workaround because rig-imported pack
commands are not currently exposed. Core workflow should not require it.

Future PackV2 target:

```toml
[defaults.rig.imports.lesson]
source = "../packs/lessons/L3"
```

Student-facing docs should give one exact edit:

```toml
default_rig_includes = ["../packs/lessons/L3"]
```

Then:

```bash
cd my-factory
gc restart
gc doctor
```

## Labels

Labels are useful for:

- provenance, such as `source:github`, `source:jira`, or `lesson:L3`
- search and reporting, such as `frontend`, `security`, or `high-risk`
- human triage, such as `needs-info` or `blocked-by-user`
- external tools that only understand labels
- demo visibility where a visible tag helps students inspect state

Labels should not be required to determine the next workflow stage when a
formula graph already knows that.

Avoid labels whose primary meaning is "route this to the next factory stage":

- `needs-plan`
- `needs-architecture`
- `needs-design`
- `needs-tests`
- `ready-to-build`
- `needs-review`
- `ready-to-ship`

If removing a label changes the workflow, the design is still label-driven.

## Orders

Use orders for real triggers:

- cooldown work
- cron work
- tracker sync
- external event handling
- optional manual dispatch

Do not use orders as the main stage-to-stage dispatch mechanism inside a
lesson factory.

Bad lesson-default pattern:

```toml
[order]
trigger = "condition"
check = "bd ready --label=needs-review --limit=1 | grep -q ."
formula = "mol-code-review"
pool = "reviewer"
```

Better lesson-default pattern:

```toml
[[steps]]
id = "review"
needs = ["build"]
metadata = { "gc.run_target" = "reviewer" }
```

## Commands

Commands are allowed, but they should be optional convenience.

Good command uses:

- `gc lesson status`
- show lesson artifacts
- reset lesson scratch files
- import demo tickets

Bad command use:

- scan labels and wake downstream agents
- implement the workflow scheduler
- hide required behavior outside formulas

## Doctors

Every runtime lesson pack should include at least one doctor check.

Recommended checks:

- `formula_v2` enabled when required
- required agents discovered
- entry formula discovered
- required binaries available
- bead store initialized
- expected lesson artifact directories writable

Doctor output should teach the pack boundary: "this lesson pack is loaded and
ready."

## Duplication Policy

Duplication is intentional in lesson packs.

Do not optimize lesson packs for DRY. Optimize them for:

- readability
- local reasoning
- resetability
- predictable student outcomes
- direct comparison between lessons

Rules:

- a lesson pack must run standalone
- a lesson pack must not require students to inspect another pack
- duplicated content may be simplified to fit the lesson goal
- changes to copied content must be reviewed per lesson
- lesson READMEs should explicitly say duplication is deliberate

Later, if maintenance cost becomes too high, generate lesson packs from shared
sources. Generated lesson packs should still be concrete folders that students
can inspect.

## Curriculum Guidance

### L2

Teaching focus: first real factory with planner and architect.

Recommended runtime:

- one self-contained L2 pack
- one entry formula
- planner and architect agents included locally
- no `packs/all`
- no activity-pack override instructions
- one `gc sling` entry command

### L3

Teaching focus: design and build workflow.

Recommended runtime:

- L3 pack duplicates L2 planner/architect if still needed
- adds designer and builder locally
- formula routes plan -> design -> build
- build step depends on design or explicit skip condition

### L4

Teaching focus: review and release control.

Recommended runtime:

- L4 pack duplicates needed prior agents
- adds reviewer and release-gate locally
- formula models pass/request-changes explicitly
- reviewer outcome changes graph path, not labels

### W3

Teaching focus: coordination.

Recommended rewrite:

- teach formula graph design directly
- gates are formula steps/checks/retries
- rejection paths are explicit formula branches or review outcomes
- keep `orchestrator.yaml` only as a comparison artifact if useful

### C1

Teaching focus: end-to-end factory run.

Recommended runtime:

- one C1 pack
- one capstone formula
- one initial `gc sling`
- formula creates/unlocks all major stages
- run report records formula state and artifacts, not manual stage bead setup

## Migration Path

1. Lock this spec as the target architecture.
2. Rewrite `plans/port-to-packs-v2.md` around lesson packs, not format-only
   migration.
3. Create `packs/lessons/L2` as proof of shape.
4. Update L2 docs to switch one lesson import and run one `gc sling`.
5. Validate the runtime on a clean factory.
6. Repeat for L3, L4, and C1.
7. Rework W3 around formulas.
8. Remove `packs/all`, label handoff, and activity override instructions from
   the primary student path.
9. Keep reusable leaf packs only as reference or compatibility material.

## Maintenance Checks

Add checks that enforce the teaching architecture:

```bash
find packs/lessons -name pack.toml -print
find packs/lessons -path '*/agents/*/agent.toml' -print
find packs/lessons -path '*/formulas/*.toml' -print
```

Search for old control-plane patterns:

```bash
rg 'gc all wake-downstream|bd ready --label|bd create .*--labels?|needs-plan|needs-architecture|ready-to-build|needs-review|ready-to-ship' \
  curriculum activities activites packs/lessons my-factory
```

Allowed matches should be explicit historical comparison callouts only.

## Acceptance Criteria

This architecture is successful when:

- each runtime lab can run from a single lesson pack
- students can inspect one folder and see all runtime definitions for that lab
- switching lessons requires one documented import edit
- starting a lesson requires one simple `gc sling` command
- lesson packs do not depend on `packs/all`
- stage progression is visible in formulas
- labels remain metadata, not the workflow state machine
- `gc all wake-downstream` is absent from lesson-critical flow
- W3 and C1 no longer teach manual stage-labelled bead creation as the ideal
- skipping ahead to L3 or L4 still produces a working lesson environment

## Non-Goals

This spec does not require:

- deleting shared packs immediately
- renaming `activites/`
- fixing upstream Gas City command exposure
- fixing upstream skill materialization
- using every FormulaV2 feature in the first migrated lesson
- rewriting every formula in one pass

The first concrete step is to make lesson-pack composition explicit and
self-contained. Formula-native cleanup can then happen lesson by lesson.
