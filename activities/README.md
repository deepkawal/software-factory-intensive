# Activities

This directory is where you do your work for each session of the Software Factory Intensive. It is separate from `../curriculum/`, which contains the walkthroughs you *read*, and separate from `../packs/`, which contains the canonical, shipped agent packs.

| Tree | What goes here |
|------|----------------|
| `workshops/W1..W4/` | Deliverables from each workshop (design docs, config files, feedback-loop notes) |
| `labs/L1..L4/` | Deliverables from each lab plus any customised pack copies |
| `capstone/C1/` | Capstone run report and retrospective |

## The additive, independent model

Every session ships a ready-to-use reference pack under `../packs/<agent>/`. The curriculum is designed so that **skipping a session does not break the pipeline** — you just include the shipped pack as-is instead of your own customised copy.

Within a session you can customise a pack two ways:

1. **Copy it** — `cp -r ../../packs/<agent> packs/<agent>/` inside the session's activity folder, edit your copy, and point your rig at the customised copy by adding a rig-scoped import to `../my-factory/city.toml`:
   ```toml
   [rigs.imports.<agent>]
   source = "../activities/<session>/packs/<agent>"
   ```
   This overrides the shipped `../packs/<agent>` for this rig only.
2. **Leave it alone** — the shipped pack is already wired via `default_rig_includes` in `city.toml.template`; focus on the workshop's conceptual deliverables.

Either way, at the end of the session you **update `../my-factory/city.toml`** to reflect which packs your rig should run. Each session's README tells you the exact lines.

## Typical session flow

1. Open `../curriculum/<session>/README.md` and read the walkthrough.
2. Work inside this session's folder (`activities/<session>/`). Most sessions ask for one or two markdown deliverables (a workflow card, a factory-wiring doc, an orchestrator.yaml, a feedback-loop note).
3. For labs that deploy a new agent: copy the shipped pack into `activities/<session>/packs/<agent>/`, customise, and wire it into `../my-factory/city.toml` using the `[rigs.imports.<agent>]` block above.
4. Run `gc restart && gc doctor` from `../my-factory/` to reload the city. (Pack-level changes also hot-reload within ~30s via the patrol tick, but `gc restart` is the reliable recovery path for nested edits.)

## Getting un-stuck

If a session breaks your factory:

1. `git checkout activities/<session>/packs/` to discard the customised pack copy.
2. Remove the `[rigs.imports.<agent>] source = "../activities/<session>/packs/<agent>"` block you added to `../my-factory/city.toml`. The shipped `../packs/<agent>` composed via `default_rig_includes` takes over again.
3. `gc restart` from `my-factory/`.

You lose the customisation but keep a working factory, and you can retry the customisation later.

## Sessions

| Session | Folder | Key deliverable |
|---------|--------|-----------------|
| W1 | [`workshops/W1/`](workshops/W1/) | Workflow card — single-agent workflow discipline |
| W2 | [`workshops/W2/`](workshops/W2/) | Factory wiring — per-agent table + integration points |
| W3 | [`workshops/W3/`](workshops/W3/) | `orchestrator.yaml` + gate justification doc |
| W4 | [`workshops/W4/`](workshops/W4/) | Feedback-loops — reactive / aggregate / external rules |
| L1 | [`labs/L1/`](labs/L1/) | Filled-in `CLAUDE.md` + `DECISIONS.md` log |
| L2 | [`labs/L2/`](labs/L2/) | First work package + ADR; Planner + Architect packs wired |
| L3 | [`labs/L3/`](labs/L3/) | Design spec + implementation; Designer + Builder packs wired |
| L4 | [`labs/L4/`](labs/L4/) | Review report + release gate; Reviewer + Release-Gate packs wired |
| C1 | [`capstone/C1/`](capstone/C1/) | Factory run report + retrospective card |
