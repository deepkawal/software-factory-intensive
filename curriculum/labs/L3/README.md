# L3: Deliver a Feature Through the Factory

> **What you will do:** switch the active factory to the L3 pack and run one
> formula that plans, architects, designs, builds, tests, and commits a small
> feature.

## Mental Model

You keep the same project rig across labs. The rig owns the project files,
beads, sessions, and artifacts. The city root chooses which factory pack is
active for that rig.

L3 uses:

```toml
[defaults.rig.imports.factory]
source = "../packs/lessons/L3"
```

The imported agents are rig-scoped, so their targets are:

```text
<rig>/factory.planner
<rig>/factory.architect
<rig>/factory.designer
<rig>/factory.builder
```

The formula is `mol-feature-delivery`:

```text
plan -> architecture -> design -> build
```

## 1. Enable FormulaV2

This is a one-time city setting. Confirm `my-factory/city.toml` contains:

```toml
[daemon]
formula_v2 = true
```

## 2. Select the L3 Factory Pack

Edit `my-factory/pack.toml` so the active factory import points at L3:

```toml
[pack]
name = "my-factory"
schema = 2

[defaults.rig.imports.factory]
source = "../packs/lessons/L3"
```

## 3. Sync the Existing Rig

Root default imports are applied when a rig is created. Because you are keeping
the same rig from L2, sync it explicitly:

```bash
cd my-factory
gc --rig <rig> import remove factory
gc --rig <rig> import add ../packs/lessons/L3 --name factory
gc restart
gc doctor
```

Use your real rig name from:

```bash
gc rig list
```

## 4. Start the Formula

```bash
gc sling <rig>/factory.planner \
  "Add a percent operation: percent(whole, fraction) returns whole*fraction/100" \
  --on mol-feature-delivery
```

Capture the workflow bead id printed by `Attached workflow ...`.

## 5. Watch Progress

Use these commands while the graph runs:

```bash
gc events --follow
gc session list
gc session peek <session-id>
gc graph <workflow-bead-id>
bd list
```

You should see the formula advance through:

```text
factory.planner -> factory.architect -> factory.designer -> factory.builder
```

Use all six observability commands from L2. Watch the four-agent handoff.

## 6. Inspect Outputs

In your project rig, verify:

```bash
ls docs/plans
ls docs/architecture
ls docs/designs
git log --oneline -5
npm test
```

Expected outputs:

- a work package in `docs/plans/`
- an architecture decision in `docs/architecture/`
- an implementation design in `docs/designs/`
- a new implementation commit
- passing tests

## 7. Attach a Capability to Designer or Builder

L3 adds two new agents. Ground one of them in a real external system — the same config-over-chat exercise from L2, targeting the new roles.

| Capability | Agent | What It Adds |
|-----------|-------|-------------|
| GitHub MCP | Builder | Create branches, read existing files |
| Sentry MCP | Builder | Check existing errors before coding |
| Context7 MCP | Designer | Up-to-date framework docs for design |

Follow the same 5-step process from L2:

1. Inspect `packs/workshop/overlay/.claude/settings.json` for examples.
2. Add the MCP to the agent's overlay under `packs/lessons/L3/agents/<agent>/overlay/.claude/settings.json`.
3. Edit the agent's `prompt.template.md` to name the capability in the Inputs section.
4. `gc restart` and re-sling with a different feature request.
5. Compare artifacts. Record what changed.

## Exit Criteria

- The run started with one `gc sling <rig>/factory.planner ... --on mol-feature-delivery`.
- No stage labels or manual downstream beads were used.
- The graph routed all four roles.
- The builder committed the implementation and tests.
- One capability attached to designer or builder with a visible artifact change.
