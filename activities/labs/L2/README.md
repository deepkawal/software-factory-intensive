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
bd create --title "Feature: <your feature>" --label needs-plan
gc sling your-project--planner <bead-id>
# ...wait for the Planner to close the bead with label needs-architecture
gc sling your-project--architect <bead-id>
```

## Exit criteria

* [ ] Planner produced a work package file in the rig with at least one user story and acceptance criteria
* [ ] Architect produced an ADR with at least two options considered
* [ ] `../../../my-factory/city.toml` uses shipped packs (default) or has `[rigs.imports.planner]` / `[rigs.imports.architect]` blocks pointing at customised copies
* [ ] Any prompt correction was made by editing the pack file and re-slinging — not by typing a correction into chat

## Skipped this session?

L3 assumes a work package + ADR exist for the feature it implements. If you skip L2, copy the reference work package and ADR into your rig (renamed for your feature) so L3 has inputs to work from.

## Recover from a broken run

* Revert the pack edit: `git checkout activities/labs/L2/packs/`
* Remove the `[rigs.imports.planner]` / `[rigs.imports.architect]` blocks from `../../../my-factory/city.toml`. The rig falls back to `default_rig_includes = ["../packs/all"]` and runs the shipped packs.
* `gc restart` — you're back on the known-good shipped packs
