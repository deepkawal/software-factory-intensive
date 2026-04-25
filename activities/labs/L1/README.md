# L1 · Build a Structured Development Loop — Activity

**Walkthrough:** [`../../../curriculum/labs/L1/README.md`](../../../curriculum/labs/L1/README.md)

L1 prepares the project that later lesson factories will operate on. It does not install a multi-agent runtime yet.

## Deliverables

Create or update these files:

- `CLAUDE.md` or `AGENTS.md` in your project rig with project-specific rules, commands, release criteria, and safety boundaries.
- `DECISIONS.md` in this activity folder with one entry per rule change.
- `../../../my-factory/PROJECT_MANIFEST.md` with the project overview, tech stack, structure, review standards, and release criteria.

## Factory State After L1

`my-factory` should be registered, FormulaV2 should be enabled in `city.toml`, and your project should be added as a rig:

```bash
cd ../../../my-factory
gc register .
gc rig add /path/to/your-project
gc doctor --fix
```

No normal feature workflow runs in L1. The first runnable formula flow starts in L2 after the L2 factory pack is selected and synced to the existing rig.

## Exit Criteria

- [ ] Project instructions file exists in the rig and contains at least five project-specific rules.
- [ ] `DECISIONS.md` records why each rule was added or changed.
- [ ] `PROJECT_MANIFEST.md` is filled in enough for Planner and Architect agents to ground their output.
- [ ] `gc status` from `../../../my-factory/` shows the city and rig.
