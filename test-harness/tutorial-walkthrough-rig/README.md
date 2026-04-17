# sfi-walkthrough-calculator

Minimal JavaScript rig used by `test-harness/tutorial-walkthrough.sh` to exercise the L2 (Planner + Architect) handoff against real live LLM agents.

This project is intentionally tiny — just enough structure for the Planner and Architect to produce a meaningful work package + ADR. Do **not** run tests here manually or treat this as a reference for real-world rig layout; it's a harness fixture.

## What the harness does with it

1. Copies this tree to `$scratch/rig/`.
2. `git init` + initial commit.
3. `gc rig add` points the scratch factory at it.
4. Files a bead `"Add a multiply function to the calculator"` with label `needs-plan`.
5. Waits for the Planner to produce `work-packages/<slug>.md` in the rig.
6. Waits for label handoff + Architect to produce `docs/adr/<slug>.md`.
7. Asserts both artifacts exist and are non-empty.
8. Tears down the scratch factory and removes the scratch dir.

## Contents

| Path | Purpose |
|---|---|
| `package.json` | Makes this a recognizable Node.js project; Jest dependency (not actually installed by the harness) |
| `src/calculator.js` | Two trivial functions the agents have room to extend |
| `test/calculator.test.js` | Passing tests that demonstrate the test conventions |
| `CLAUDE.md` | Minimal project rules the Planner reads for context |

## Why Node.js

The package.json + src/ + test/ shape is immediately recognizable to any coding agent. Any language would work; Node was chosen for zero build-tool ceremony and because the Planner/Architect agents don't actually execute code — they just read the tree and produce markdown.
