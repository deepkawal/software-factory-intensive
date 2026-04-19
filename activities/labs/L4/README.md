# L4 · Deploy Reviewer + Release-Gate Agents — Activity

**Walkthrough:** [`../../../curriculum/labs/L4/README.md`](../../../curriculum/labs/L4/README.md)
**Reference examples:**
* [`../../../reference-project/fired-up-pizza/review-reports/loyalty-points-review.md`](../../../reference-project/fired-up-pizza/review-reports/loyalty-points-review.md)
* [`../../../reference-project/fired-up-pizza/release-gates/loyalty-points-gate.md`](../../../reference-project/fired-up-pizza/release-gates/loyalty-points-gate.md)

## Deliverables

* One review report (Reviewer output) — lands in your rig at `<your-project>/review-reports/<slug>-review.md`
* One release gate (Release-Gate output) — lands at `<your-project>/release-gates/<slug>-gate.md`
* A `notes.md` in this folder: at least one reviewer finding that you resolved by editing the Builder's pack prompt (not by hand-editing code)

**Naming note:** the curriculum calls this role *Deployer*. The shipped pack is named `release-gate` — same role, same output. Every `packs/deployer` reference in older curriculum material should be read as `packs/release-gate`.

## Pack wiring

Packs live at `../../../packs/reviewer/` and `../../../packs/release-gate/`, already wired into every rig via `default_rig_includes = ["../packs/all"]` in `city.toml.template`.

**(a) Use shipped packs as-is:** nothing to wire — `packs/all` already contains reviewer and release-gate. Skip straight to restart.

**(b) Customise:**

```bash
mkdir -p packs
cp -r ../../../packs/reviewer packs/reviewer
cp -r ../../../packs/release-gate packs/release-gate
```

Then override the shipped packs for your rig only by adding rig-scoped imports to `../../../my-factory/city.toml`:

```toml
[[rigs]]
name = "your-project"
# ...existing fields...

[rigs.imports.reviewer]
source = "../activities/labs/L4/packs/reviewer"

[rigs.imports.release-gate]
source = "../activities/labs/L4/packs/release-gate"
```

Restart:

```bash
cd ../../../my-factory
gc restart
gc doctor      # should be green for all eight agents
```

## Running the lab

From your project rig:

```bash
# After L3's Builder has committed to the feature branch:
bd create --title "Review: <feature>" --labels needs-review
gc sling --nudge your-project/reviewer.reviewer <bead-id>

# Once you see review-reports/<slug>-review.md (and have addressed findings
# via Builder-pack prompt edits if needed), hand off to the Release-Gate:
bd create --title "Ship: <feature>" --labels ready-to-ship
gc sling --nudge your-project/release-gate.release-gate <bead-id>
```

**Flag notes:**
- `--labels` (plural). `--label` (singular) is not a valid flag.
- `--nudge` on `gc sling` kicks the agent into processing.
- Each pipeline stage gets its own new bead. If you want an explicit dep edge for audit, add it after the fact with `bd link <new> <upstream>`.

## Exit criteria

* [ ] Review report produced with findings at Low/Medium/High severity
* [ ] At least one finding was resolved by editing `packs/builder/agents/builder/prompt.template.md` (shipped or your copy) and re-slinging — no hand-edits to code in response to reviewer findings
* [ ] Release gate emitted with a clear PASS / FAIL verdict plus evidence per required check
* [ ] All six agents ran (shipped via `default_rig_includes`, or customised copies via `[rigs.imports.<agent>]` blocks)

## Skipped this session?

C1 assumes all six agents are running. Shipped `packs/all` includes them all via `default_rig_includes` in the factory's `city.toml.template`, so even without L4 the capstone still runs — just without your review-standards customisations.

## When an agent seems stuck

If the Reviewer or Release-Gate session dies silently mid-task — `gc session list` shows no session and no artifact appears — clear the assignee and re-sling with `--force`:

```bash
bd update <stuck-bead-id> --assignee ""
gc sling --nudge --force your-project/<agent>.<agent> <stuck-bead-id>
```

See L2's troubleshooting section for full symptoms and explanation. This is common enough on multi-minute LLM stages (Reviewer in particular) that you should expect to do it at least once during a real session.

## Recover from a broken run

* Revert: `git checkout activities/labs/L4/packs/`
* Remove the `[rigs.imports.reviewer]` / `[rigs.imports.release-gate]` blocks from `../../../my-factory/city.toml`. The rig falls back to `default_rig_includes = ["../packs/all"]` and runs the shipped packs.
* `gc restart && gc doctor`
