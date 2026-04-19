# sfi-walkthrough-calculator — agent rules

This is a minimal JavaScript calculator rig used by the SFI tutorial-walkthrough harness. Treat it as a real project with the rules below; the harness will measure whether your output follows them.

## Tech stack

- JavaScript (CommonJS modules, `require`/`module.exports`)
- Node's built-in `node:test` for testing — run `node --test`
- No build tooling — source runs directly under Node
- Zero production dependencies; zero devDependencies

## Project structure

- `src/` — implementation files
- `test/` — test files (one per src file, named `<name>.test.js`, using `node:test`)
- `work-packages/` — Planner output, one markdown file per feature
- `docs/adr/` — Architect output: Architecture Decision Records, numbered `NNNN-<slug>.md`
- `docs/design/` — Designer output: one design spec per feature
- `review-reports/` — Reviewer output: `<slug>-review.md`
- `release-gates/` — Release-Gate output: `<slug>-gate.md`

## Conventions

- Export functions via `module.exports = { foo, bar }`
- Every new src file needs a matching test file with at least one happy-path test
- Prefer small pure functions over classes
- Builder should commit each feature on a `feature/<slug>` branch — never straight to main

## Handoff expectations (full 6-agent pipeline)

Each agent, on finishing its own artifact, should **close its own bead** (`bd close <your-bead-id>`). Do not relabel the bead to the next stage — the next bead for the next agent is created separately by the operator once they've reviewed your artifact. Relabeling is actively wrong because it creates two beads with the same stage label, which confuses the downstream agent's scale_check.

| Stage        | Produces                                      | On finish                 |
|--------------|-----------------------------------------------|---------------------------|
| Planner      | `work-packages/<slug>.md`                     | `bd close <your-bead>`    |
| Architect    | `docs/adr/NNNN-<slug>.md`                     | `bd close <your-bead>`    |
| Designer     | `docs/design/<slug>.md`                       | `bd close <your-bead>`    |
| Builder      | code + tests on `feature/<slug>` branch       | `bd close <your-bead>`    |
| Reviewer     | `review-reports/<slug>-review.md`             | `bd close <your-bead>`    |
| Release-Gate | `release-gates/<slug>-gate.md` (PASS/FAIL)    | `bd close <your-bead>`    |

Do not run `gc all wake-downstream` and do not create the next stage's bead — that is the operator's job, not yours.

## Artifact content requirements

- **Planner** → Work Package: at least one user story and 3+ acceptance criteria; include sections like `## User Story`, `## Acceptance Criteria`, `## Out of Scope`.
- **Architect** → ADR: sections `## Context`, `## Options Considered` (≥2 options), `## Decision` with rationale.
- **Designer** → Design spec: sections covering interface, behavior/edge cases, and a test plan.
- **Reviewer** → Review report: each finding labelled with severity (Critical / High / Medium / Low), location, impact, and suggested fix.
- **Release-Gate** → Gate report: explicit `PASS` or `FAIL` verdict plus evidence per check.

These match the shipped pack prompts and are what the harness asserts against.
