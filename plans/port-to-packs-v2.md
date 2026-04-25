# Port Curriculum to PackV2 Lesson Packs

## Status

This plan replaces the earlier format-only PackV2 migration plan.

The old plan treated the existing reusable leaf packs, `packs/all`, stage
labels, label-gated orders, and `gc all wake-downstream` as the desired runtime
shape. That is no longer the target. The target is a curriculum-first PackV2
architecture:

- each runtime lesson has one self-contained pack
- the lesson pack contains the full factory for that lesson
- formulas express workflow structure
- labels are metadata, not the control plane
- student commands stay minimal because the pack carries the defaults

## Decision Summary

Recommended decision: build self-contained lesson packs under
`packs/lessons/<lesson>/` and make those the primary student runtime surface.

The existing reusable leaf packs can remain only if they are either updated to
the same formula-native model or explicitly quarantined as legacy comparison
material. Students should not need to understand `packs/all` to complete a
lesson.

Recommended student mental model:

```text
choose lesson pack -> restart city -> sling one request -> formula routes work
```

Not:

```text
create stage-labelled bead -> order sees label -> command scans labels ->
sling downstream agent -> downstream prompt polls label queue
```

## What PackV2 and FormulaV2 Actually Want

PackV2 is convention-loaded. A pack is a directory with a `pack.toml` plus
standard subdirectories such as:

```text
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

The pack directory is the definition. `agents/foo/` defines an agent. A formula
file in `formulas/` defines a formula. Top-level `orders/*.toml` defines
orders. Students should be able to inspect one pack folder and see what runs.

FormulaV2 is graph-capable. It supports dependencies, children, loops,
conditions, checks, retries, dynamic follow-on bonding, graph routing, and
per-step metadata. That means the formula can carry the factory flow instead
of delegating the flow to labels and shell scripts.

For graph-first lesson workflows:

```toml
formula = "mol-l3-factory"
version = 2
contract = "graph.v2"
```

and the city needs:

```toml
[daemon]
formula_v2 = true
```

For routing a graph step to an agent, prefer:

```toml
metadata = { "gc.run_target" = "designer" }
```

Do not use stage labels such as `needs-design` as the primary routing
mechanism. Formula routing resolves `gc.run_target`, stamps runtime routing
metadata, and lets Gas City's work-query/reconciler path do the rest.

Curriculum policy: active lesson formulas use FormulaV2 syntax from the first
formula lesson. This avoids teaching FormulaV1 and then forcing a dialect switch
when multi-agent routing appears. The course should still introduce FV2
gradually: simple steps first, then dependencies, then `gc.run_target`, then
larger graph features only when a lesson actually needs them.

## Issues in Current Material

### 1. The current plan is format-only

The previous migration plan preserved the existing topology: reusable leaf
packs, `packs/all`, checkpoint pack copies, label handoffs, and helper
commands. That would produce PackV2-shaped files but keep the wrong teaching
model.

New direction: PackV2 migration is also a content architecture migration.

### 2. `packs/all` hides the factory

Current docs make `packs/all` the default composition pack. It imports all
agent packs and hosts the `wake-downstream` command. This optimizes reuse, but
it makes students chase behavior through multiple packs.

Problem:

- lesson docs point at one activity
- agents live in separate packs
- formulas live in separate packs
- the flow lives partly in labels
- the dispatch command lives in `packs/all`
- the city imports `packs/all`

New direction: each lesson pack contains the lesson's whole factory. `packs/all`
must not be the student runtime path. If it remains, it must be marked and
tested as legacy/reference material.

### 3. Stage labels are acting as the workflow engine

Current labels include:

- `needs-architecture`
- `needs-plan`
- `needs-design`
- `needs-tests`
- `ready-to-build`
- `needs-review`
- `ready-to-ship`

These are not just tags. They encode stage routing. Orders watch them, prompts
poll them, formulas add/remove them, and `wake-downstream` scans them.

New direction: formulas own stage order and dependencies. Labels remain useful
for provenance, filtering, and reporting.

### 4. Orders are used as label queue dispatchers

Current per-agent orders have checks like:

```toml
check = "bd ready --label=needs-plan --limit=1 | grep -q ."
```

That makes every stage an external queue rather than a formula step.

New direction: use orders only for real external triggers:

- cooldown/background maintenance
- cron-like sync jobs
- external tracker import
- optional manual entrypoints

Do not use orders as the normal handoff path between formula steps.

### 5. `gc all wake-downstream` is a custom scheduler

Current formulas close or relabel beads, then call:

```bash
gc all wake-downstream &
```

That command scans stage labels and slings one matching bead per downstream
agent. It exists partly because rig-imported pack commands are not exposed in
the current Gas City implementation, so `packs/all` is imported at both
workspace and rig scope.

New direction: remove this command from lesson-critical flow. Graph formulas
should make downstream steps ready directly.

### 6. Prompts tell agents to poll labels forever

Current prompts tell agents to run patterns like:

```bash
sleep 60 && bd ready --label=needs-plan
```

and never stop polling.

That is not the graph-worker model. For graph-first formulas, agents should
work the ready bead assigned or routed to them, close it with outcome metadata,
briefly check for more assigned work, then drain when idle.

New direction: lesson agents should use GraphV2-style prompt guidance:

- inspect assigned/routed work
- do the current step
- close with pass/fail metadata
- let formula/control flow unlock next work

### 7. Formulas manually create and relabel beads

Several formulas create child beads with labels or relabel the current bead for
the next stage. For example, planner creates children with `needs-design`,
`needs-tests`, or `ready-to-build`; builder relabels to `needs-review`; reviewer
relabels to `ready-to-build` or `ready-to-ship`.

New direction: model those as formula steps, dependencies, conditions, checks,
and routes. Use step descriptions for judgment, but keep graph structure in the
formula.

### 8. W3 teaches a separate `orchestrator.yaml`

The W3 activity asks students to write an external six-stage orchestrator file
that references labels and artifact paths.

New direction: if the activity is about coordination, the coordination artifact
should be a formula or formula design review, not a parallel orchestration DSL.

### 9. Capstone creates fresh beads per stage

The capstone tells students to manually create one bead for each stage and
attach a stage label.

New direction: capstone should start with one request. The capstone formula
should create or unlock the planner, architect, designer, builder, reviewer,
and release steps.

### 10. Activities teach pack override mechanics

The activity README currently teaches copying a shipped pack into an activity
folder, editing it, and changing rig imports to override the shipped version.

New direction: activities should produce lesson deliverables. Runtime behavior
should come from the lesson pack for that session. If a lesson asks students to
edit a pack, they edit the active lesson pack.

### 11. Current curriculum still contains v1 or stale command shapes

Examples still mention old syntax and old paths, including:

- `includes = [ ... ]`
- `[[agent]]`
- `version = 1` lesson formulas
- `prompts/<agent>.md.tmpl`
- `overlays/default`
- label-stage commands
- manual `bd create --labels <stage>`
- `gc all wake-downstream`

New direction: rewrite student-facing docs around one PackV2 import, FormulaV2
lesson formulas, and one entry command per lab.

### 12. Status commands reinforce label queues

Pack status commands currently report `bd ready --label=<stage>`.

New direction: lesson status commands should report formula/molecule state,
ready assigned work, or lesson artifacts. Do not make labels the primary status
view.

### 13. Skills and overlays are mixed with runtime workarounds

Gas City currently discovers pack-root and agent-local skill catalogs, but the
active materializer does not stage all of them consistently. The current packs
duplicate skills through agent overlay directories.

New direction: keep necessary duplicated skills inside each lesson pack's agent
overlay until upstream materialization is reliable. Document this as a runtime
compatibility workaround, not as a teaching concept.

### 14. The `activites/` checkpoint tree duplicates stale behavior

The misspelled `activites/` tree contains checkpoint copies with the same
label-driven patterns. It can be preserved temporarily for historical
checkpoint compatibility, but it should not define the new student runtime
path.

New direction: migrate active teaching to `packs/lessons/*`. Retire checkpoint
runtime dependency after lesson packs exist.

## Full Implementation Scope

This port is not complete when the docs merely describe a better architecture.
It is complete only when the repository's runnable materials behave that way.

The migration must update all active file families:

- canonical packs under `packs/`
- new self-contained lesson packs under `packs/lessons/`
- checkpoint pack copies under `activites/` if they remain reachable from docs
  or tests
- scripts embedded in pack commands, doctors, orders, formulas, and assets
- `my-factory/city.toml` and `my-factory/pack.toml`
- all student-facing Markdown in `README.md`, `activities/`, `curriculum/`,
  `my-factory/`, `packs/`, and `reference-project/`
- dry-run/static validation scripts in `test-harness/`
- walkthrough scripts in `test-harness/walkthroughs/`
- harness documentation in `test-harness/README.md`

Anything left on the old label-dispatch model must be explicitly moved to a
legacy/reference path and excluded from the student runtime path. A stale pack,
script, or README that still appears in a lesson is a migration bug.

## Current Files That Must Move

The current inventory shows stale behavior in these concrete areas:

- `packs/all/commands/wake-downstream/*`
- `packs/*/agents/*/agent.toml`
- `packs/*/agents/*/prompt.template.md`
- `packs/*/formulas/*.toml`
- `packs/*/orders/*.toml`
- `packs/*/commands/*/run.sh`
- `packs/*/doctor/*/run.sh`
- `packs/*/README.md`
- `my-factory/city.toml`
- `my-factory/pack.toml`
- `my-factory/README.md`
- `README.md`
- `activities/README.md`
- `activities/labs/*/README.md`
- `activities/workshops/*/README.md`
- `activities/capstone/C1/README.md`
- `curriculum/**/README.md`
- `curriculum/**/PROMPT.md`
- `reference-project/**`
- `activites/**/packs/**`
- `test-harness/README.md`
- `test-harness/migration-check.sh`
- `test-harness/tutorial-check.sh`
- `test-harness/tutorial-walkthrough.sh`
- `test-harness/behavioral-smoke.sh`
- `test-harness/walkthroughs/_common.sh`
- `test-harness/walkthroughs/*.sh`

The implementation task is to update these files or explicitly remove them from
the active student path. The plan should not leave any active lesson depending
on an unexamined pack, script, or Markdown page.

## Pack And Script Work

This work includes deletion. Do not preserve commands, orders, formulas,
imports, prompts, scripts, or docs just because they already exist. If a thing
does not serve the formula-native lesson model, remove it from the active pack.
If it is useful only as a comparison to the old system, move or mark it as
legacy and keep it out of the student runtime path.

### Self-contained lesson packs

Create one pack per runnable lesson:

```text
packs/lessons/
  L2/
  L3/
  L4/
  C1/
```

Add W packs only where the workshop has a runnable factory experience that is
cleared by a pack:

```text
packs/lessons/
  W3/
  W4/
```

Each lesson pack is the factory for that lesson. It must contain:

- `pack.toml`
- every agent definition used by the lesson
- every agent prompt used by the lesson
- every formula used by the lesson
- any commands, doctors, orders, overlays, and assets needed by the lesson
- any local skill or context material that students need to inspect

Lesson packs must not import other packs. Duplication is intentional. Students
should be able to open one folder and understand the whole runnable lesson.

### Canonical packs

The existing canonical packs are currently part of the stale teaching surface:

- `packs/planner`
- `packs/architect`
- `packs/designer`
- `packs/builder`
- `packs/validator`
- `packs/reviewer`
- `packs/release-gate`
- `packs/improver`
- `packs/fired-up-pizza`
- `packs/workshop`
- `packs/all`

These packs must be updated or retired from the active path. It is not enough
to create lesson packs while leaving canonical packs teaching the old behavior.

Removal is expected for anything whose only purpose was label dispatch,
including redundant commands, stage-queue orders, wake-downstream glue,
composition imports, and status scripts that only summarize label queues.

For every role pack:

- update `agents/*/agent.toml` so nudges point at formula-native work, not
  `bd ready --label=...`
- update `agents/*/prompt.template.md` so the agent handles assigned/routed
  formula work and drains when idle instead of polling stage labels forever
- update active `formulas/*.toml` to FormulaV2 syntax; use graph steps,
  dependencies, and `metadata."gc.run_target"` where the pack remains in the
  active lesson path
- remove formula actions that create the next stage only by adding labels
- remove formula actions that call `gc all wake-downstream`
- update `orders/*.toml` so orders are not stage-label queue dispatchers
- update `commands/*/run.sh` so status and helper commands report formula state,
  assigned work, artifacts, or optional external sync state
- update `doctor/*/run.sh` so doctors validate the pack's actual FormulaV2 and
  PackV2 expectations
- update `README.md` so it explains the role pack as reference material or a
  formula-native helper, not as part of the primary student path

`packs/all` must stop being the default factory. Remove dependencies on it from
active lesson packs, `my-factory`, docs, and tests. The `wake-downstream`
command should be deleted from active packs. If kept for comparison, it belongs
in a clearly named legacy/reference location and every reference to it must say
that it demonstrates the older label-dispatch approach.

`packs/fired-up-pizza` should either become the capstone's self-contained
lesson pack source or be reduced to project fixtures and optional import
helpers. It must not be the place where the workflow secretly lives.

`packs/workshop` may keep environment doctors and external tracker sync helpers,
but those helpers are support tools. They should not be required to understand
normal lesson flow.

### Checkpoint pack copies

The `activites/` tree contains checkpoint copies of packs. For every checkpoint
that remains documented or tested:

- update the copied pack to the same formula-native behavior as the lesson pack
- remove stage-label orders and label-polling prompts
- remove `gc all wake-downstream`
- keep any differences limited to the lesson checkpoint's intended exercise

Recommended end state: active lessons use `packs/lessons/*`; checkpoint pack
copies are either deleted later or marked as frozen historical artifacts.

### Pack scripts

All scripts must follow the same conceptual model as the content:

- commands start or inspect formulas, artifacts, or external sync; they do not
  advance stages by scanning labels
- doctors check prerequisites and pack health; they do not hide missing runtime
  wiring behind label queue checks
- orders handle external triggers or scheduled maintenance; they do not encode
  the primary lesson workflow
- formula helper scripts, if any, operate on the current formula step and
  artifact contract

The following script patterns should disappear from active lesson paths:

```bash
bd ready --label=needs-plan
bd ready --label=needs-architecture
bd ready --label=needs-design
bd ready --label=needs-tests
bd ready --label=ready-to-build
bd ready --label=needs-review
bd ready --label=ready-to-ship
gc all wake-downstream
```

If labels remain in scripts, they must be metadata filters, reporting aids, or
external tracker tags. They must not be the state machine.

## Markdown Content Work

Every student-facing Markdown file must show the same lesson model:

1. select the lesson's self-contained pack in `my-factory/city.toml`
2. restart or reload Gas City
3. run the lesson's simplest `gc sling` command
4. inspect the formula, graph state, artifacts, and beads that were produced
5. make the lesson-specific edit or observation
6. rerun the same simple entrypoint or the lesson's documented verification

The docs should minimize CLI surface area. Prefer pack-defined behavior over
long command sequences. When students need to use a CLI, use the fewest commands
with the simplest arguments:

```bash
gc restart
gc doctor
gc sling <entry-target> "lesson request"
bd list
bd show <id>
```

Avoid making students manually create stage beads. Avoid teaching `bd` labels
before they have seen formula-created work.

Required doc updates:

- `README.md`: describe lesson-pack switching, not `packs/all` as the default
  factory
- `my-factory/README.md`: show the active lesson import, one `gc sling`
  entrypoint, and formula/artifact inspection
- `my-factory/city.toml`: default to the current starting lesson pack, not
  `../packs/all`
- `my-factory/pack.toml`: remove inherited `packs/all` comments and old
  `wake-downstream` command guidance
- `activities/README.md`: remove the pack-copy override model as the main path;
  teach lesson packs as the runtime surface
- `activities/labs/*/README.md`: rewrite step-by-step lab commands around the
  active lesson pack and its formula
- `activities/workshops/W3/README.md`: replace `orchestrator.yaml` as the main
  artifact with formula graph design or make it an explicit comparison
- `activities/workshops/W4/README.md`: update feedback/improvement flow to use
  formula-native handoff
- `activities/capstone/C1/README.md`: replace six manual stage beads with one
  capstone request and formula-driven stages
- `curriculum/**/README.md` and `curriculum/**/PROMPT.md`: mirror the activity
  changes so instructor and student tracks do not diverge
- `packs/**/README.md`: explain each pack's current role after migration
- `reference-project/**`: update project examples, reports, and workflow
  artifacts so they either reflect formula-native flow or are labeled as legacy
  comparison material
- `test-harness/README.md`: document the new validation model and walkthrough
  expectations

Content that may remain as historical comparison must say so in the file itself
and must not be referenced as the primary way to complete a lesson.

## Dry-Run And Walkthrough Harness Work

The harness must test the content architecture, not preserve the old journey.

### Dry-run/static checks

Update the dry-run checks so they fail when active lesson paths contain:

- `packs/all` as a runtime dependency
- `gc all wake-downstream`
- `bd create --label` or `bd create --labels` as a lesson stage entrypoint
- `bd ready --label=<stage>` as workflow dispatch
- stage-routing labels as required workflow state
- prompt instructions to poll labels forever
- FormulaV2 files missing graph routing metadata where multi-agent routing is
  expected
- active lesson formulas using `version = 1`
- lesson packs with imports
- lesson docs that omit the required `city.toml` lesson-pack switch

The dry-run should also verify positive structure:

- every documented runnable lesson has `packs/lessons/<lesson>/pack.toml`
- every lesson pack has its local agents and formulas
- every multi-agent lesson formula uses graph dependencies and
  `metadata."gc.run_target"`
- every lesson README contains the one-command sling entrypoint
- every lesson's expected artifacts are named consistently between docs,
  formulas, and tests

### Walkthrough scripts

Rewrite walkthrough helpers around formulas rather than labels.

`test-harness/walkthroughs/_common.sh` should stop modeling stages as labels.
Replace helpers such as `stage_bead_create` and `run_stage <label> ...` with
helpers that:

- switch the active lesson pack
- run the documented `gc sling` entrypoint
- wait for formula-created/routed work
- inspect generated artifacts
- assert that no label-scanning handoff command was required
- assert that the tutorial transcript matches the Markdown commands

Update these walkthroughs:

- `test-harness/walkthroughs/L2.sh`
- `test-harness/walkthroughs/L3.sh`
- `test-harness/walkthroughs/L4.sh`
- `test-harness/walkthroughs/C1.sh`
- `test-harness/walkthroughs/my-factory.sh`

The walkthroughs should execute what the lesson docs tell students to execute.
If a walkthrough needs a hidden setup step, the docs or harness comments must
make clear that it is test scaffolding, not student workflow.

### Behavioral smoke

Update behavioral smoke expectations from label handoff to formula handoff.
Instead of proving that planner relabels work and `wake-downstream` slings the
next agent, prove that:

- the lesson's entry sling attaches or cooks the expected formula
- formula graph steps become visible
- ready work is routed to the intended agent targets
- pass/fail outcomes unlock the next graph step or branch
- artifacts are written to the documented locations
- the run completes without `gc all wake-downstream`

## Target Directory Shape

Runtime lessons live under:

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

Not every conceptual workshop needs a full runtime factory immediately. The
first migration should prioritize runtime-heavy lessons:

1. `L2`
2. `L3`
3. `L4`
4. `C1`
5. `W3` if the coordination exercise remains runtime-backed
6. the remaining workshops/labs as needed

Each lesson pack is self-contained:

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
      run.sh
      doctor.toml
  commands/
    status/
      run.sh
      command.toml
  skills/
  template-fragments/
  examples/
```

Rules:

- no `[imports.*]` inside lesson packs unless the lesson is explicitly teaching
  imports
- no dependency on `packs/all`
- no dependency on shared leaf packs
- duplicate agents/formulas when needed
- keep lesson-specific simplifications local to the lesson pack

## Lesson Pack `pack.toml`

Minimal shape:

```toml
[pack]
name = "sfi-l3"
schema = 2
```

If most agents share the same default formula:

```toml
[agent_defaults]
default_sling_formula = "mol-l3-factory"
```

If agents need different default formulas, put `default_sling_formula` in each
`agents/<name>/agent.toml` instead.

Do not add old PackV1 declarations:

- no `[[agent]]`
- no `[formulas]`
- no `[[commands]]`
- no `[[doctor]]`
- no `pack.includes`

## Agent Defaults

The current Gas City runtime applies only a narrow set of agent defaults
reliably. Use defaults where they reduce student commands:

- `default_sling_formula`
- `append_fragments`

Keep essential per-agent values in `agents/<name>/agent.toml`:

```toml
scope = "rig"
wake_mode = "fresh"
max_active_sessions = 1
default_sling_formula = "mol-l3-factory"
nudge = "Run gc prime, then work the assigned formula step."
```

Avoid teaching `work_query` and `sling_query` unless the lesson is specifically
about routing internals. Default routing is good enough for the student path.

## Formula Pattern

A lesson should have one visible entry formula:

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

Use FormulaV2 syntax even for the first simple formula lesson. The beginner
formula may only have the header plus plain steps and `needs`; it does not need
multi-agent routing until the lesson teaches multi-agent work.

Teaching progression:

- first formula lesson: `version = 2`, `contract = "graph.v2"`, simple steps
- dependency lesson: add `needs = [...]`
- multi-agent lesson: add `metadata = { "gc.run_target" = "planner" }`
- larger workflow lesson: add `children` only if grouping makes inspection
  clearer
- validation lesson: add `check` or `retry` only if retry behavior is being
  taught

Use formula features before shell workarounds:

- `needs` for stage order
- `metadata.gc.run_target` for agent routing
- `children` for inspectable subwork when the graph is large enough to need it
- `condition` for optional steps when the lesson needs a clear branch
- `check` or `retry` for validation and retry behavior when that behavior is
  being taught

Avoid advanced FV2 constructs in the first pass:

- `loop`
- dynamic `on_complete` fanout
- formula expansion or advice
- scope/cleanup/control-dispatcher patterns

Do not encode core flow through:

- `bd update --add-label <next-stage>`
- `bd create --label <next-stage>`
- `gc all wake-downstream`
- `bd ready --label <stage>`

## Simplest Student CLI

The lesson pack should carry enough defaults that students do not need to know
the bead lifecycle just to start a lab.

Preferred per-lesson run command:

```bash
gc sling <rig>/planner "Build user profile editing"
```

This works when the target agent has `default_sling_formula` configured in the
lesson pack. Gas City creates/routes the bead and attaches the lesson formula.

If a lesson needs to make formula attachment explicit:

```bash
gc sling <rig>/planner "Build user profile editing" --on mol-l3-factory
```

Avoid making the normal path:

```bash
bd create --title "Build user profile editing" --label needs-plan
gc sling --nudge <rig>/planner <bead-id>
```

That teaches two tools and a stage label before the student has seen the
factory.

## City Switching

Current compatibility shape:

```toml
[workspace]
default_rig_includes = ["../packs/lessons/L3"]
```

If lesson pack commands must be exposed as `gc <binding> <cmd>`, add the same
lesson pack at workspace scope:

```toml
[imports.lesson]
source = "../packs/lessons/L3"
```

That dual import is a current Gas City implementation workaround. It should not
be needed for core lesson flow if the lesson uses formulas and doctors rather
than pack commands for handoff.

Future PackV2 target shape:

```toml
[defaults.rig.imports.lesson]
source = "../packs/lessons/L3"
```

Student-facing docs should present exactly one line to change per lesson.

## Commands and Doctors

Use `doctor/` for readiness checks:

- required binaries
- `formula_v2` enabled where needed
- expected agents present
- expected formulas present
- project has beads initialized

Use `commands/` for optional convenience only:

- status summaries
- artifact display
- reset helpers

Do not put lesson handoff logic in commands.

## Labels

Allowed uses:

- `lesson:L3`
- `source:lesson-pack`
- `artifact:design`
- `risk:security`
- `needs-info`
- external tracker labels

Avoid stage-routing labels:

- `needs-plan`
- `needs-architecture`
- `needs-design`
- `needs-tests`
- `ready-to-build`
- `needs-review`
- `ready-to-ship`

If a label appears in a lesson formula, it should be removable without changing
the workflow graph.

## Migration Phases

### Phase 1: Lock The Architecture Contract

Update:

- `plans/port-to-packs-v2.md`
- `specs/content-architecture.md`

Purpose: make the new target explicit and prevent further work on the old
format-only migration.

Deliverable: this plan names every active file family that must move, and the
spec names the student-facing rules those files must obey.

### Phase 2: Build The First Complete Lesson Pack

Build `packs/lessons/L2` first.

Requirements:

- self-contained
- no imports
- includes every agent needed for L2
- one visible entry formula
- no `packs/all`
- no `gc all wake-downstream`
- no stage-label order handoff
- student starts with one `gc sling` command
- formulas express the lesson workflow with graph steps and route metadata
- prompts describe formula-routed work instead of label polling
- scripts inspect or validate formula state instead of dispatching labels

Use this lesson to validate the PackV2 and FormulaV2 teaching shape before
duplicating work across L3/L4/C1.

### Phase 3: Rewrite L2 Content And Harness Together

Update L2 docs and walkthrough so students:

1. choose `../packs/lessons/L2`
2. run `gc restart`
3. run one `gc sling` command
4. inspect `packs/lessons/L2`
5. inspect formula-created workflow state

Update at the same time:

- `activities/labs/L2/README.md`
- `curriculum/labs/L2/README.md`
- `curriculum/labs/L2/PROMPT.md`
- any L2 checkpoint under `activites/`
- `test-harness/walkthroughs/L2.sh`
- shared walkthrough helpers touched by L2

Remove instructions and tests that require copying shared packs, editing
per-rig import overrides, creating stage-labelled beads, or running
label-specific status commands.

### Phase 4: Port The Remaining Runtime Lessons

Port each lesson as a self-contained pack. Duplicate definitions from earlier
lessons intentionally.

Recommended order:

1. `L3` - first multi-agent build lesson
2. `L4` - review/release lesson
3. `C1` - end-to-end factory run

Each lesson should simplify what came before, not just copy all previous
complexity forward.

For each lesson, update all three layers in the same change:

- pack and scripts
- Markdown lesson content
- dry-run and walkthrough coverage

### Phase 5: Convert Canonical Packs Or Quarantine Them

Update the canonical role packs so they no longer teach label-dispatch, or move
them out of the active teaching path.

Required work includes deleting stale material, not just editing it in place:

- `packs/*/agents/*/agent.toml`: formula-native nudges/default formulas
- `packs/*/agents/*/prompt.template.md`: no label-polling loops
- `packs/*/formulas/*.toml`: graph/routing/dependency flow
- `packs/*/orders/*.toml`: external triggers only, not stage queues
- `packs/*/commands/*/run.sh`: status/inspection only, not handoff
- `packs/*/doctor/*/run.sh`: validate PackV2/FormulasV2 expectations
- `packs/*/README.md`: reference/helper positioning
- delete role-pack files whose only job was old label-queue dispatch

`packs/all` gets special handling: retire it from the default factory path and
remove `wake-downstream` from every active lesson. If the command remains, move
it to a legacy comparison surface.

### Phase 6: Rework W3 Coordination

Replace `orchestrator.yaml` as the main runtime concept.

Recommended teaching move:

- W3 students design or review a formula graph
- gates are formula steps or check/retry/gate constructs
- rejection paths are formula branches or explicit review outcomes

Keep `orchestrator.yaml` only as a comparison artifact if the lesson explicitly
contrasts external orchestration with formula-native orchestration.

### Phase 7: Rewrite The Markdown Surface

After lesson packs exist, rewrite or quarantine student-facing references to:

- `packs/all` as default runtime
- `gc all wake-downstream`
- stage-label startup
- label polling loops
- `bd create --labels <stage>` capstone flow
- old `includes = [...]` / `[[agent]]` / `prompts/*.md.tmpl` examples
- `orchestrator.yaml` as the normal workflow engine

This phase covers `README.md`, `activities/`, `curriculum/`, `my-factory/`,
`packs/`, `reference-project/`, and `test-harness/README.md`.

### Phase 8: Update Dry-Run And Walkthrough Harness

Rewrite harness expectations to enforce the new architecture:

- static checks fail on old dispatch patterns in active lesson paths
- dry-run verifies lesson pack shape and formula graph routing
- walkthrough scripts execute the same commands shown in Markdown
- behavioral smoke proves formula handoff, not label handoff
- harness docs explain formula-native validation

### Phase 9: Clean Checkpoints And Legacy References

Decide whether `activites/` checkpoints are still needed.

Recommended answer: keep them only until lesson packs cover the same learning
goals. Then replace checkpoint runtime instructions with lesson pack pointers
and mark any remaining checkpoint copy as historical.

## Grill-Me Decision Tree

Question: Should lesson packs import shared base packs to avoid duplication?

Recommended answer: no. The user-facing lesson pack should be fully
self-contained. DRY can be restored later with generation if maintenance cost
becomes painful.

Question: Should labels disappear completely?

Recommended answer: no. Keep labels for provenance and reporting. Remove labels
as the stage router.

Question: Should orders disappear completely?

Recommended answer: no. Keep orders for external triggers and scheduled work.
Do not use orders as the normal formula step handoff mechanism.

Question: Should every workshop get a runtime pack?

Recommended answer: only when the workshop requires running a factory. Start
with runtime-heavy labs and capstone. Add workshop packs where they clarify the
lesson.

Question: Should the capstone still create one bead per stage?

Recommended answer: no. Capstone should start from one user request. The
capstone formula creates or unlocks the staged work.

Question: Should we use `default_sling_formula`?

Recommended answer: yes, where it reduces student CLI. It lets the pack define
the lesson formula so students can start with `gc sling <target> "request"`.

Question: Should we rely on pack commands for workflow handoff?

Recommended answer: no. Pack commands are useful, but rig-imported command
exposure is currently limited. More importantly, putting handoff in a command
teaches the wrong abstraction.

Question: Should FormulaV2 be mandatory for active lesson formulas?

Recommended answer: yes. Use FormulaV2 syntax from the first formula lesson so
students do not learn FormulaV1 and then switch halfway through. Keep the early
FormulaV2 formulas simple: header, steps, and `needs`. Add `gc.run_target`,
`children`, `condition`, `check`, or `retry` only when the lesson needs that
specific concept.

Question: Should students edit `city.toml` every lesson?

Recommended answer: yes, but only one documented import line. Anything more is
too much configuration ceremony for a lesson switch.

Question: Should students learn `bd create` early?

Recommended answer: not as the lab entrypoint. Introduce `bd` after they have
seen Gas City create and route work from a simple `gc sling` command.

## Acceptance Criteria

The migration is on track when:

- `packs/lessons/L2` exists and runs standalone
- L2 docs use one active lesson pack import
- L2 starts with one `gc sling` command
- active L2 lesson formulas use `version = 2` and `contract = "graph.v2"`
- no L2-critical flow uses `packs/all`
- no L2-critical flow uses `gc all wake-downstream`
- no L2-critical flow uses stage-label orders
- formulas route work with `gc.run_target`
- labels in L2 are metadata only
- L2 walkthrough follows the Markdown commands
- dry-run checks fail if L2 reintroduces label dispatch
- `gc doctor` from `my-factory` reports expected compatibility warnings only

The migration is complete when:

- L2, L3, L4, and C1 each have self-contained lesson packs
- any runnable W lesson that needs a factory has a self-contained lesson pack
- student docs no longer teach `packs/all` as the main factory
- capstone starts from one request, not six manually-created stage beads
- W3 coordination is taught through formulas or an explicit comparison to
  formulas
- canonical packs are either formula-native or clearly marked as legacy and
  excluded from active lessons
- checkpoint copies under `activites/` are either formula-native or clearly
  marked as historical and excluded from active lessons
- all pack scripts, doctors, orders, formulas, and prompts obey the same
  formula-native workflow model
- all active lesson formulas use FormulaV2 syntax; FormulaV1 appears only in
  legacy/reference material
- all student-facing Markdown gives accurate, complete, step-by-step commands
  for the active lesson pack
- dry-run/static checks enforce the content architecture
- walkthrough scripts execute the documented steps for every runnable lesson
- behavioral smoke proves formula graph routing rather than label scanning
- reference-project artifacts either reflect formula-native flow or are clearly
  labeled historical comparison

## Verification Commands

Static checks for old workflow patterns:

```bash
rg 'gc all wake-downstream|bd ready --label|bd create .*--labels?|needs-plan|needs-architecture|ready-to-build|needs-review|ready-to-ship' \
  README.md curriculum activities activites my-factory packs reference-project test-harness
```

The result should be empty in the new lesson path except explicit historical
comparison callouts.

Static checks for old pack composition:

```bash
rg 'packs/all|default_rig_includes = \["../packs/all"\]|wake-downstream' \
  README.md curriculum activities activites my-factory packs reference-project test-harness
```

Any match must be either deleted from the student path or marked as historical
comparison.

Pack shape checks:

```bash
find packs/lessons -name pack.toml -print
find packs/lessons -path '*/agents/*/agent.toml' -print
find packs/lessons -path '*/formulas/*.toml' -print
```

Lesson packs should have no imports:

```bash
rg '^\s*\[imports|^\s*\[\[imports|source\s*=' packs/lessons
```

Expected result: no cross-pack imports. Local files and local asset references
are fine.

Formula routing checks:

```bash
rg 'version\s*=\s*2|contract\s*=\s*"graph.v2"|gc.run_target|needs\s*=' packs/lessons
```

Every active lesson formula should show FormulaV2 syntax. Every multi-agent
lesson formula should also show dependencies and routing metadata.

FormulaV1 should be absent from active lesson packs:

```bash
rg 'version\s*=\s*1' packs/lessons
```

Expected result: no matches.

Runtime smoke test for each lesson:

```bash
cd my-factory
gc restart
gc doctor
gc sling <rig>/<entry-agent> "Small feature request"
```

Then verify:

- the lesson formula is attached or cooked
- graph steps are visible
- routed steps target the intended agents
- no label-scanning handoff command is needed
- lesson artifacts land where the README says they will

Harness checks after the port:

```bash
test-harness/migration-check.sh
test-harness/tutorial-check.sh
test-harness/tutorial-walkthrough.sh --dry-run
test-harness/behavioral-smoke.sh
```

The harness must fail if Markdown, packs, or scripts drift back toward the
label-dispatch workflow.

## Out of Scope

- deleting existing reusable packs immediately if they are clearly quarantined
- renaming `activites/` to `activities`
- fixing upstream Gas City command exposure or skill materialization
- remote pack imports
- making every FormulaV2 feature part of the first formula lesson
- expanding the curriculum to new agent roles beyond the current lesson goals
