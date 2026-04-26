# L4: Review and Gate a Delivered Feature

> **What you will do:** switch the active factory to the L4 pack and run one
> formula that plans, architects, designs, builds, reviews, and gates a small
> feature.

## Mental Model

L4 keeps the same process shape as L3 and adds two downstream evidence steps:

```text
plan -> architecture -> design -> build -> review -> release-check
```

The factory pack is selected in `my-factory/pack.toml`:

```toml
[defaults.rig.imports.factory]
source = "../packs/lessons/L4"
```

The imported agents are rig-scoped:

```text
<rig>/factory.planner
<rig>/factory.architect
<rig>/factory.designer
<rig>/factory.builder
<rig>/factory.reviewer
<rig>/factory.release-gate
```

## 1. Confirm FormulaV2

Confirm `my-factory/city.toml` contains:

```toml
[daemon]
formula_v2 = true
```

## 2. Select the L4 Factory Pack

Edit `my-factory/pack.toml`:

```toml
[pack]
name = "my-factory"
schema = 2

[defaults.rig.imports.factory]
source = "../packs/lessons/L4"
```

## 3. Sync the Existing Rig

```bash
cd my-factory
gc --rig <rig> import remove factory
gc --rig <rig> import add ../packs/lessons/L4 --name factory
gc restart
gc doctor
```

## 4. Start the Formula

```bash
gc sling <rig>/factory.planner \
  "Add a clamp operation: clamp(x, lo, hi) returns x bounded to [lo, hi]" \
  --on mol-delivery-review
```

Capture the workflow bead id printed by `Attached workflow ...`.

## 5. Watch Progress

```bash
gc events --follow
gc session list
gc session peek <session-id>
gc graph <workflow-bead-id>
bd list
```

You should see:

```text
factory.planner -> factory.architect -> factory.designer -> factory.builder -> factory.reviewer -> factory.release-gate
```

Use the observability commands from L2. Watch for review findings and release verdicts in the event stream.

## 6. Inspect Outputs

In your project rig:

```bash
ls docs/plans
ls docs/architecture
ls docs/designs
ls docs/reviews
ls docs/releases
git log --oneline -5
npm test
```

Expected outputs:

- plan, architecture, and design artifacts
- implementation commit and passing tests
- review report with severity-labelled findings
- release gate with a clear `PASS` or `FAIL`

## 7. Prove the Manifest is Load-Bearing

Before this step, flesh out `my-factory/PROJECT_MANIFEST.md`:

- Add at least 4 Review Standards with checkable rules and severity mapping
- Add at least 6 Release Criteria with binary PASS/FAIL gates and evidence sources

Then re-sling with a new feature:

```bash
gc sling <rig>/factory.planner \
  "Add a <different feature>" --on mol-delivery-review
```

Compare the review and release-gate artifacts from this run to the previous run:

- The reviewer should cite your Review Standards by name
- The release gate should evaluate each Release Criterion individually

If the manifest change produced no visible difference, the reviewer or release-gate prompt needs to reference the manifest more explicitly — which is itself a W4 feedback rule.

## Exit Criteria

- The run started with one `gc sling <rig>/factory.planner ... --on mol-delivery-review`.
- No stage labels or manual downstream beads were used.
- The formula routed all six roles.
- The release gate includes an explicit verdict backed by evidence.
- Manifest load-bearing test completed — reviewer cited Review Standards from PROJECT_MANIFEST.md.
