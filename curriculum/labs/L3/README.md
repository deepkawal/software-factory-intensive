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

## 7. Add a Skill to the Builder

L2 taught MCP integration (external tool access). L3 teaches skill integration — project-specific instructions that shape how an agent works.

PackV2 packs have a `skills/` directory. Each skill is a subdirectory with a `SKILL.md` file.

1. Create a testing-conventions skill for the builder:

       mkdir -p packs/lessons/L3/agents/builder/skills/testing-conventions
       $EDITOR packs/lessons/L3/agents/builder/skills/testing-conventions/SKILL.md

   Contents:

   ```markdown
   ---
   name: testing-conventions
   description: Project-specific testing conventions for the calculator.
   ---

   These rules are mandatory for all test files in this project:

   - Import `assert` from `node:assert/strict` and use `assert.strictEqual` for every comparison. Never use `assert.equal` or `assert.ok` for value checks.
   - Structure every test file with `describe()` blocks. Each exported function gets its own `describe('functionName', () => { ... })` block. Do NOT use bare `test()` calls at the top level.
   - Inside each `describe()` block, use `it()` for individual test cases, not `test()`.
   - Include at least one edge case per function: zero input, negative input, and boundary values.
   - Each `it()` description must state the expected behavior, not the implementation detail.
   ```

2. Edit the builder prompt to reference the skill:

       $EDITOR packs/lessons/L3/agents/builder/prompt.template.md

   Add to the Inputs section: "Before writing tests, read the testing-conventions skill and follow its rules for assert methods, describe blocks, and edge cases."

3. Restart and re-sling with a different feature:

       gc restart
       gc sling <rig>/factory.planner "Add a <different feature>" \
         --on mol-feature-delivery

4. Compare the builder's test code from the two commits. The second commit should use `assert.strictEqual` (not `assert.equal`), `describe()` blocks, and explicit edge case tests — because the skill told it to.

MCPs give agents access to external data. Skills give agents project-specific instructions. Both are config, not chat.

## Exit Criteria

- The run started with one `gc sling <rig>/factory.planner ... --on mol-feature-delivery`.
- No stage labels or manual downstream beads were used.
- The graph routed all four roles.
- The builder committed the implementation and tests.
- Testing-conventions skill added to builder with visible impact on test code (assert.strictEqual, describe blocks).
