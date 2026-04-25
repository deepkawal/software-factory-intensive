# W3 · Architect Multi-Agent Coordination

W3 is where you design coordination as a FormulaV2 graph. The lesson factories already contain runnable examples; your job is to learn when to add steps, dependencies, checks, retries, and human gates.

## Goal

Produce a graph design note that explains how your factory should coordinate work without turning labels into the workflow engine.

## 1. Read A FormulaV2 Graph

Open the L4 graph:

```bash
sed -n '1,260p' packs/lessons/L4/formulas/mol-delivery-review.toml
```

Look for:

- `contract = "graph.v2"`
- `[[steps]]`
- `id`
- `needs`
- `metadata."gc.run_target"`
- artifact metadata

Each step is a unit of work. `needs` defines dependency order. `gc.run_target` defines which bound agent receives that step.

## 2. Draw The Smallest Useful Graph

Create:

```bash
mkdir -p activities/workshops/W3
$EDITOR activities/workshops/W3/formula-design.md
```

Start with the smallest graph that would handle a normal feature in your project:

```text
plan -> architecture -> design -> build -> validate -> review -> release
```

Then remove any step that is not useful for your project. A formula should be as small as the work requires, not as large as the org chart.

## 3. Decide Where Judgment Lives

For each judgment, choose the right home:

| Judgment | Best Home |
|---|---|
| "What problem are we solving?" | Planner prompt |
| "Which architecture should we choose?" | Architect prompt |
| "What code shape is expected?" | Designer prompt |
| "Did implementation satisfy tests?" | Validator step |
| "Is this safe to ship?" | Release gate step |
| "Should this branch retry?" | Formula check, condition, or explicit human loop |

Dependency closure alone does not mean success. If a failed step should change the path, encode that with an explicit check, condition, retry, or manual re-run rule.

## 4. Specify Step Contracts

For each step in your graph, record:

- step ID
- target
- upstream needs
- expected inputs
- expected artifact
- close condition
- failure behavior

Example:

```text
Step: review
Target: factory.reviewer
Needs: validate
Inputs: diff, design spec, validation report, project rules
Artifact: docs/reviews/<slug>.md
Close condition: findings are grouped by severity
Failure behavior: human edits factory config or code, then re-runs the formula
```

## 5. Add Optional Branches Only When They Teach Something

Use the simple linear graph unless a branch makes the factory clearer.

Good reasons to branch:

- validator and reviewer can run independently after build
- a security review applies only when touched files match sensitive paths
- release gate should stop if validation fails

Bad reasons to branch:

- showing every feature FormulaV2 supports
- mirroring every team name
- replacing a clear prompt with a complicated graph

## 6. Compare Against C1

Open the capstone formula:

```bash
sed -n '1,320p' packs/lessons/C1/formulas/mol-release-delivery.toml
```

Compare it with your design note. Mark:

- one step you would keep
- one step you would simplify
- one check you would add for your real project

## Exit Criteria

- [ ] `activities/workshops/W3/formula-design.md` exists.
- [ ] It lists step IDs, targets, dependencies, artifacts, and close behavior.
- [ ] It explains where success/failure judgment lives.
- [ ] It avoids using metadata labels as the primary routing mechanism.

## Next

L4 uses a graph with review and release-gate steps. The review loop remains student-driven: read the review, update code or factory config, and re-run the formula when needed.
