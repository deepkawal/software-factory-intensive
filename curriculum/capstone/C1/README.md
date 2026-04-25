# C1: Run the Full Release Delivery Factory

> **What you will do:** switch the active factory to the C1 pack and run the
> full formula graph from feature request through release gate.

## Mental Model

C1 is the whole factory as one graph:

```text
plan -> architecture -> design -> build -> validate -> review -> release
```

The factory pack is selected in `my-factory/pack.toml`:

```toml
[defaults.rig.imports.factory]
source = "../packs/lessons/C1"
```

The imported agents are rig-scoped:

```text
<rig>/factory.planner
<rig>/factory.architect
<rig>/factory.designer
<rig>/factory.builder
<rig>/factory.validator
<rig>/factory.reviewer
<rig>/factory.release-gate
```

## 1. Confirm FormulaV2

Confirm `my-factory/city.toml` contains:

```toml
[daemon]
formula_v2 = true
```

## 2. Select the C1 Factory Pack

Edit `my-factory/pack.toml`:

```toml
[pack]
name = "my-factory"
schema = 2

[defaults.rig.imports.factory]
source = "../packs/lessons/C1"
```

## 3. Sync the Existing Rig

```bash
cd my-factory
gc --rig <rig> import remove factory
gc --rig <rig> import add ../packs/lessons/C1 --name factory
gc restart
gc doctor
```

## 4. Start the Formula

```bash
gc sling <rig>/factory.planner \
  "Add a multiply operation: multiply(a, b) returns a*b" \
  --on mol-release-delivery
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
factory.planner -> factory.architect -> factory.designer -> factory.builder -> factory.validator -> factory.reviewer -> factory.release-gate
```

## 6. Inspect Outputs

In your project rig:

```bash
ls docs/plans
ls docs/architecture
ls docs/designs
ls docs/validation
ls docs/reviews
ls docs/releases
git log --oneline -5
npm test
```

Expected outputs:

- plan, architecture, and design artifacts
- implementation commit and passing tests
- validation report with test evidence
- review report with severity-labelled findings
- release gate with a clear `PASS` or `FAIL`

## Exit Criteria

- The run started with one `gc sling <rig>/factory.planner ... --on mol-release-delivery`.
- No stage labels or manual downstream beads were used.
- The formula routed all seven roles.
- The release gate includes an explicit verdict backed by validation and review evidence.
