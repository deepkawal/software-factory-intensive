# L3 · Deploy Designer + Builder Agents — Activity

**Walkthrough:** [`../../../curriculum/labs/L3/README.md`](../../../curriculum/labs/L3/README.md)
**Reference example:** [`../../../reference-project/fired-up-pizza/design/loyalty-points-spec.md`](../../../reference-project/fired-up-pizza/design/loyalty-points-spec.md)

## Deliverables

* One design spec (Designer output) — lands in your rig at `<your-project>/design/<slug>-spec.md`
* Implementation commits (Builder output) — new files under your rig's `src/`, on a feature branch
* A `notes.md` in this folder: bead IDs, sling counts, and any prompt edits that moved the Builder from failing → passing

**Naming note:** the curriculum calls this role *Coder*. The shipped pack is named `builder` — same agent, same output. Every `packs/coder` reference in older curriculum material should be read as `packs/builder`.

## Pack wiring

Packs live at `../../../packs/designer/` and `../../../packs/builder/`, already wired into every rig via `default_rig_includes = ["../packs/all"]` in `city.toml.template`.

**(a) Use shipped packs as-is:** nothing to wire — `packs/all` already contains designer and builder. Skip straight to restart.

**(b) Customise:**

```bash
mkdir -p packs
cp -r ../../../packs/designer packs/designer
cp -r ../../../packs/builder packs/builder
```

Then override the shipped packs for your rig only by adding rig-scoped imports to `../../../my-factory/city.toml`:

```toml
[[rigs]]
name = "your-project"
# ...existing fields...

[rigs.imports.designer]
source = "../activities/labs/L3/packs/designer"

[rigs.imports.builder]
source = "../activities/labs/L3/packs/builder"
```

Restart:

```bash
cd ../../../my-factory
gc restart
gc doctor
```

## Running the lab

From your project rig:

```bash
# After L2's Architect has written its ADR:
bd create --title "Design: <feature>" --labels needs-design
gc sling --nudge your-project/designer.designer <bead-id>

# Once you see docs/design/<slug>.md, hand off to the Builder:
bd create --title "Build: <feature>" --labels ready-to-build
gc sling --nudge your-project/builder.builder <bead-id>
```

**Flag notes:**
- `--labels` (plural). `--label` (singular) is not a valid flag.
- `--nudge` on `gc sling` kicks the agent into processing.
- Each pipeline stage gets its own new bead. If you want an explicit dep edge for audit, add it after the fact with `bd link <new> <upstream>`.

## Exit criteria

* [ ] Design spec written with Props / Interactions / Edge Cases / Test Plan sections
* [ ] Builder committed working code to a feature branch; `npm test` (or your test runner) passes
* [ ] Zero manual code edits — every Builder correction was a prompt edit to `packs/builder/agents/builder/prompt.template.md` (shipped or your copy) followed by a re-sling
* [ ] Designer + Builder ran successfully (shipped packs via `default_rig_includes`, or customised copies via `[rigs.imports.designer]` / `[rigs.imports.builder]`)

## Skipped this session?

L4 (review) runs on committed code from some feature branch. If you skipped L3, either copy the reference project's feature branch verbatim into your rig, or reduce L4 to reviewing a trivial hand-written commit — note the deviation in C1's run report.

## When an agent seems stuck

If an agent's session dies silently mid-task — `gc session list` shows no session and no artifact appears — clear the assignee and re-sling with `--force`:

```bash
bd update <stuck-bead-id> --assignee ""
gc sling --nudge --force your-project/<agent>.<agent> <stuck-bead-id>
```

See L2's troubleshooting section for full symptoms and explanation.

## Recover from a broken run

* Revert: `git checkout activities/labs/L3/packs/`
* Remove the `[rigs.imports.designer]` / `[rigs.imports.builder]` blocks from `../../../my-factory/city.toml`. The rig falls back to `default_rig_includes = ["../packs/all"]` and runs the shipped packs.
* `gc restart` — the shipped packs always pass their doctor checks
