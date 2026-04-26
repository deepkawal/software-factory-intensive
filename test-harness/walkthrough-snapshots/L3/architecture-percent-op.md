# Percent Operation Architecture

## Context

The calculator project exposes `add` and `subtract` from a single module
(`src/calculator.js`). A new `percent(whole, fraction)` function is requested
that returns `whole * fraction / 100`. The planner asks the architect to decide
whether `percent` belongs in the existing module or in a new file.

The project has zero dependencies, CommonJS modules, and a one-file-per-module
test convention. There are currently two exported functions.

## Options Considered

### Option A — Add `percent` to `src/calculator.js`

Add the function alongside `add` and `subtract` in the existing module and
export it from the same `module.exports` object.

**Pros:**
- Follows the established single-module pattern.
- No new files, no new import paths for consumers.
- Keeps the project minimal — one source file, one test file.
- All arithmetic lives in one place; easy to discover.

**Cons:**
- The module grows with each new operation. At scale this could become unwieldy.
- Unrelated operations share a single file (though all are pure arithmetic).

### Option B — Create a new `src/percent.js` module

Place `percent` in its own file with a matching `test/percent.test.js`.

**Pros:**
- Each operation is independently importable.
- File-level isolation makes diffs and blame cleaner per feature.

**Cons:**
- Breaks the existing convention without a clear forcing function — three
  functions across two files is premature splitting.
- Consumers must know which file to import from.
- Adds a second source file and a second test file for a single-expression
  function, increasing surface area for no structural benefit.

## Decision

**Option A — add `percent` to `src/calculator.js`.**

Rationale: the project convention is a single arithmetic module. Three small
pure functions in one file is well within reasonable size. Splitting creates
import-path fragmentation and file overhead that isn't justified until the
module grows meaningfully (e.g., 8+ functions or mixed concerns). When that
threshold is reached, a future ADR can revisit module decomposition.

The function signature is `percent(whole, fraction)` returning
`whole * fraction / 100`. No input validation beyond what JavaScript provides
natively — non-numeric arguments will naturally produce `NaN`, which is the
standard JS arithmetic behavior and matches how `add` and `subtract` behave
today. The designer should confirm this in the design spec.

## Consequences

- `src/calculator.js` exports `{ add, subtract, percent }`.
- `test/calculator.test.js` gains test cases for `percent` covering the four
  acceptance-criteria inputs.
- No new files, no new dependencies, no changes to `add` or `subtract`.
- Future operations should follow the same pattern until the module warrants
  decomposition.

## Risks

- **Low — module growth:** If many operations are added later, the single file
  could become large. Mitigated by revisiting when the module exceeds ~8
  exports.
- **Low — floating-point precision:** `whole * fraction / 100` can produce
  IEEE 754 artifacts for some inputs. The plan's acceptance criteria
  (`percent(99.99, 50) === 49.995`) is representable exactly, so no rounding
  logic is needed now. If precision guarantees are required later, a dedicated
  ADR should evaluate fixed-point or rounding strategies.

## References

- Planning artifact: `docs/plans/percent-op.md`
- Project conventions: `CLAUDE.md`
