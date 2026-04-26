# Percent Operation Architecture

## Context

The calculator project currently exposes two pure functions (`add`, `subtract`)
from a single module `src/calculator.js`. A new `percent(whole, fraction)`
function is requested that returns `whole * fraction / 100`. The planner's open
question asks whether `percent` belongs in the existing module or in a new file.

The project conventions favour small pure functions in one module, CommonJS
exports, zero dependencies, and a 1:1 mapping between src and test files.

## Options Considered

### Option A: Add `percent` to `src/calculator.js`

Add the function directly alongside `add` and `subtract` in the existing module
and export it from the same `module.exports` object.

**Pros:**

- Matches the established pattern — every arithmetic operation lives in one
  file, every consumer imports from one place.
- No new files, no new test files, no import-path changes.
- Keeps the export surface predictable: `require('./calculator')` gives you
  everything.

**Tradeoffs:**

- The module grows by ~3 lines of code. At this scale the growth is negligible,
  but the pattern sets a precedent — if dozens of operations are added later, a
  single file becomes unwieldy.

### Option B: Create a new `src/percent.js` module

Place `percent` in its own file with a dedicated `test/percent.test.js`.

**Pros:**

- Each function is independently locatable and testable.
- Scales better if the project eventually has many operations.

**Tradeoffs:**

- Breaks the current "one module, many functions" convention without a forcing
  reason — the project has only three functions.
- Adds file-management overhead (new src file, new test file, new import path)
  for a single three-line function.
- Consumers must now know which file exports which operation, reducing
  discoverability.

## Decision

**Option A — add `percent` to `src/calculator.js`.**

The project is small, the existing convention is clear, and `percent` is
arithmetically equivalent in complexity to `add` and `subtract`. Splitting to a
new module introduces overhead with no concrete benefit at the current scale.
If the module grows past ~8–10 exported functions in the future, that is the
appropriate time to revisit and split by category.

## Consequences

- `src/calculator.js` gains one new exported function; `module.exports` adds
  `percent`.
- `test/calculator.test.js` gains the corresponding test cases.
- No new files, no dependency changes, no build changes.
- The single-module convention is explicitly preserved and documented as the
  default until the function count warrants a split.

## Risks

- **Module bloat over time.** Mitigated by the stated threshold (~8–10
  functions) at which the team should revisit. Low risk given the current
  trajectory.
- **Floating-point precision.** `whole * fraction / 100` uses native JS
  floating-point arithmetic. For example, `percent(1, 3)` returns `0.03` — this
  is acceptable per the planner's scope boundary (rounding behaviour is out of
  scope). If precision becomes a requirement later, it is a new feature, not an
  architectural change.

## References

- Planning artifact: `docs/plans/percent.md`
- Project conventions: `CLAUDE.md` (Calculator Project Agent Rules)
- Existing source: `src/calculator.js`
