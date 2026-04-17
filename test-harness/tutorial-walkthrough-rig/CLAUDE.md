# sfi-walkthrough-calculator — agent rules

This is a minimal JavaScript calculator rig used by the SFI tutorial-walkthrough harness. Treat it as a real project with the rules below; the harness will measure whether your output follows them.

## Tech stack

- JavaScript (CommonJS modules, `require`/`module.exports`)
- Jest for testing
- No build tooling — source runs directly under Node

## Project structure

- `src/` — implementation files
- `test/` — Jest test files (one per src file, named `<name>.test.js`)
- `docs/adr/` — Architecture Decision Records, numbered `NNNN-<slug>.md`
- `work-packages/` — Planner output, one markdown file per feature

## Conventions

- Export functions via `module.exports = { foo, bar }`
- Every new src file needs a matching test file with at least one happy-path test
- Prefer small pure functions over classes
- No external dependencies beyond Jest (devDependency only)

## Deliverables

- **Planner** writes to `work-packages/<slug>.md` — one user story, 3+ acceptance criteria
- **Architect** writes to `docs/adr/NNNN-<slug>.md` — at least 2 options considered + one decision with rationale

These are the only two artifacts produced during the L2 slice of the walkthrough.
