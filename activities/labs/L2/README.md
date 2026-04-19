# L2 · Deploy Planner + Architect Agents — Activity

**Walkthrough:** [`../../../curriculum/labs/L2/README.md`](../../../curriculum/labs/L2/README.md)
**Reference examples:**
* [`../../../reference-project/fired-up-pizza/work-packages/loyalty-points-system.md`](../../../reference-project/fired-up-pizza/work-packages/loyalty-points-system.md)
* [`../../../reference-project/fired-up-pizza/docs/adr/0001-loyalty-points-storage.md`](../../../reference-project/fired-up-pizza/docs/adr/0001-loyalty-points-storage.md)

## Deliverables

* One work package file (Planner output) — lands in your project's rig, typically at `<your-project>/work-packages/<slug>.md`
* One ADR file (Architect output) — lands at `<your-project>/docs/adr/NNNN-<slug>.md`
* A short `notes.md` in this folder recording the bead IDs, sling counts, and any pack-prompt edits you made

## Pack wiring

The two packs are already shipped under `../../../packs/planner/` and `../../../packs/architect/`, and they're already wired into every rig via `default_rig_includes = ["../packs/all"]` in `city.toml.template` (packs/all is the composition pack that imports all 8 agents). Two paths forward:

**(a) Use shipped packs as-is** — fastest, no city.toml edit needed.

```bash
cd ../../../my-factory
gc restart
gc doctor         # both actual-planner:check-planner and actual-architect:check-architect should pass
```

**(b) Customise** — if the shipped prompts don't match your project's voice.

```bash
mkdir -p packs
cp -r ../../../packs/planner packs/planner
cp -r ../../../packs/architect packs/architect
# edit packs/planner/agents/planner/prompt.template.md and packs/architect/agents/architect/prompt.template.md
```

Then override the shipped packs for your rig only by adding rig-scoped imports to `../../../my-factory/city.toml`:

```toml
[[rigs]]
name = "your-project"
# ...existing fields...

[rigs.imports.planner]
source = "../activities/labs/L2/packs/planner"

[rigs.imports.architect]
source = "../activities/labs/L2/packs/architect"
```

## Running the lab

From your project rig:

```bash
# Start the Planner on the feature:
bd create --title "Feature: <your feature>" --labels needs-plan
gc sling --nudge your-project--planner <bead-id>

# Once you see work-packages/<slug>.md, hand off to the Architect:
bd create --title "Architecture: <your feature>" --labels needs-architecture
gc sling --nudge your-project--architect <bead-id>
```

**Flag notes:**
- `--labels` (plural). `--label` (singular) is not a valid flag.
- `--nudge` on `gc sling` kicks the agent into processing.
- Each pipeline stage gets its own new bead. If you want an explicit dep edge for audit, add it after the fact with `bd link <new> <upstream>`.

## Exit criteria

* [ ] Planner produced a work package file in the rig with at least one user story and acceptance criteria
* [ ] Architect produced an ADR with at least two options considered
* [ ] `../../../my-factory/city.toml` uses shipped packs (default) or has `[rigs.imports.planner]` / `[rigs.imports.architect]` blocks pointing at customised copies
* [ ] Any prompt correction was made by editing the pack file and re-slinging — not by typing a correction into chat

## Skipped this session?

L3 assumes a work package + ADR exist for the feature it implements. If you skip L2, copy the reference work package and ADR into your rig (renamed for your feature) so L3 has inputs to work from.

## When an agent seems stuck

Sometimes an agent's session dies silently mid-task — the bead stays open, `gc session list` shows no session for that agent, and no artifact ever appears. The dead session left its assignee on the bead, so the reconciler (which filters `--unassigned`) can't spawn a replacement.

To unstick:

```bash
bd update <stuck-bead-id> --assignee ""
gc sling --nudge --force your-project--<agent> <stuck-bead-id>
```

`--force` overwrites the stale `gc.routed_to` metadata so the re-sling actually routes. You should see a new session spawn within one tick (~20s) and the agent pick up where it left off.

Symptoms this is the right fix:
- `gc session list` shows no active session for the agent.
- `bd show <bead-id>` shows `Assignee: <agent-template>-1` but the agent isn't running.
- Artifact file hasn't appeared and no new activity in the last few minutes.

## Recover from a broken run

* Revert the pack edit: `git checkout activities/labs/L2/packs/`
* Remove the `[rigs.imports.planner]` / `[rigs.imports.architect]` blocks from `../../../my-factory/city.toml`. The rig falls back to `default_rig_includes = ["../packs/all"]` and runs the shipped packs.
* `gc restart` — you're back on the known-good shipped packs
