# C1 · Run the Software Factory End-to-End — Activity

**Walkthrough:** [`../../../curriculum/capstone/C1/README.md`](../../../curriculum/capstone/C1/README.md)
**Reference examples:**
* [`../../../reference-project/fired-up-pizza/factory-run-report.md`](../../../reference-project/fired-up-pizza/factory-run-report.md)
* [`../../../reference-project/fired-up-pizza/retrospective-card.md`](../../../reference-project/fired-up-pizza/retrospective-card.md)

## Deliverables

Two files in this folder:

* `factory-run-report.md` — structured record of the end-to-end run: feature, pipeline results per stage (sling counts, config changes), timeline, ad-hoc-prompt count (target: zero), feedback-rule triggers, success-criteria check, artifacts produced.
* `retrospective-card.md` — Keep / Change / Question (one short paragraph each) plus a one-line summary for the team.

## Pack wiring

By the start of C1, all six packs should already be included in `../../../my-factory/city.toml` from L2 through L4. Confirm with:

```bash
cd ../../../my-factory
gc doctor
```

All of `actual-planner:check-planner`, `actual-architect:check-architect`, `actual-designer:check-designer`, `actual-builder:check-builder`, `actual-reviewer:check-reviewer`, and `actual-release-gate:check-release-gate` should be green. (`gc doctor` prefixes check IDs with the pack name.)

All six packs are included by default via `default_rig_includes = ["../packs/all"]` in `my-factory/city.toml.template` — `packs/all` is a composition pack that imports all 8 agents. There is nothing to wire before the capstone run unless you want to override a specific pack with a customised copy, in which case add a rig-scoped block to `../../../my-factory/city.toml`:

```toml
[[rigs]]
name = "your-project"
# ...existing fields...

[rigs.imports.builder]
source = "../activities/labs/L3/packs/builder"   # your customised builder, for example
```

## Running the capstone

1. Pick a new feature from your backlog (not one used during the labs).
2. File the root bead and sling the Planner. After each upstream agent's artifact appears in the rig, create the next stage's bead and sling:

   ```bash
   bd create --title "Feature: <name>" --labels needs-plan
   gc sling --nudge your-project/planner.planner <bead-id>

   bd create --title "Architecture: <name>" --labels needs-architecture
   gc sling --nudge your-project/architect.architect <bead-id>

   bd create --title "Design: <name>" --labels needs-design
   gc sling --nudge your-project/designer.designer <bead-id>

   bd create --title "Build: <name>" --labels ready-to-build
   gc sling --nudge your-project/builder.builder <bead-id>

   bd create --title "Review: <name>" --labels needs-review
   gc sling --nudge your-project/reviewer.reviewer <bead-id>

   bd create --title "Ship: <name>" --labels ready-to-ship
   gc sling --nudge your-project/release-gate.release-gate <bead-id>
   ```

   Log every sling, every prompt edit, and every ad-hoc chat correction.
3. At the end, draft `factory-run-report.md` using the reference report as the template.
4. Write `retrospective-card.md` — one Keep, one Change, one Question.

**Flag notes:**
- `--labels` (plural), not `--label`.
- `--nudge` on every `gc sling`.
- Each stage is a new bead. If you want explicit dep edges for audit, add them after the fact with `bd link <new> <upstream>`.

## Exit criteria

* [ ] All six pipeline stages produced artifacts in the rig (work package → ADR → design spec → code → review report → release gate)
* [ ] `factory-run-report.md` and `retrospective-card.md` present in this folder
* [ ] Ad-hoc prompt count recorded (target: 0 — every correction via pack-prompt edit)
* [ ] Every prompt edit made during the run is committed alongside the artifact that motivated it

## Skipped sessions upstream?

The run still works — the factory uses whichever packs you wired in, shipped or customised. Call out the skipped sessions explicitly in the run report under "Prior-session deviations" so the retrospective can identify what to revisit.

## When an agent seems stuck

Across a six-stage capstone you should expect at least one agent session to die silently — the bead stays open, `gc session list` shows no session for that agent, and no artifact appears. Clear the assignee and re-sling with `--force`:

```bash
bd update <stuck-bead-id> --assignee ""
gc sling --nudge --force your-project/<agent>.<agent> <stuck-bead-id>
```

Record each rescue in the run report under "Ad-hoc operator interventions" — the capstone's target is zero ad-hoc corrections, and rescues count against that target. Fewer rescues = more stable run.

See L2's troubleshooting section for full symptoms and explanation.

## Recover from a broken run mid-capstone

* Abandon the feature branch, reset the bead, and re-sling from the stage that failed.
* If a pack edit during the run is the cause, `git checkout` that specific file to its pre-run state and re-sling.
* Record everything in the run report — a capstone that required three resets still teaches more than one that ran cleanly.
