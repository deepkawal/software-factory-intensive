# Negate Operation Architecture

## Context

The calculator project exports `add`, `subtract`, and `percent` from a single
module (`src/calculator.js`). A new `negate(x)` function is requested that
returns `-x`, giving users a unary sign-flip operation. The planner asks the
architect to decide whether `negate` belongs in the existing module or warrants
a separate file, given the project's "small pure functions" convention.

The project has zero dependencies, CommonJS modules, and a one-file-per-module
test convention. There are currently three exported functions. A prior ADR
(`docs/architecture/percent-op.md`) established the precedent of co-locating
new arithmetic operations in `calculator.js` until the module exceeds roughly
eight exports.

## Options Considered

### Option A — Add `negate` to `src/calculator.js`

Add the function alongside `add`, `subtract`, and `percent` in the existing
module and export it from the same `module.exports` object.

**Pros:**
- Follows the established single-module convention and the `percent-op` ADR
  precedent.
- No new files, no new import paths for consumers.
- Four small pure functions in one file is well within reasonable size.
- Unary and binary arithmetic operations live together; easy to discover.

**Cons:**
- `negate` is the first unary operation; the module has so far only contained
  binary operations. This is a minor conceptual difference, not a structural one.
- The module continues to grow, though four exports is still far below the ~8
  threshold.

### Option B — Create a new `src/negate.js` module

Place `negate` in its own file with a matching `test/negate.test.js`.

**Pros:**
- File-level isolation; each operation is independently importable.
- Unary operations separated from binary ones by file boundary.

**Cons:**
- Breaks the convention established by the `percent-op` ADR without a forcing
  function — a single one-liner function does not justify a new module.
- Consumers must know which file to import from.
- Adds two new files (source + test) for a single-expression function,
  increasing surface area for no structural benefit.
- Sets a precedent that every new operation gets its own file, which fragments
  the project prematurely.

## Decision

**Option A — add `negate` to `src/calculator.js`.**

Rationale: the prior ADR for `percent` established that new arithmetic
operations belong in the single calculator module until it grows past ~8
exports. Adding `negate` brings the total to four — well within that threshold.
The unary-vs-binary distinction is not a meaningful architectural boundary for
single-expression pure functions.

The function signature is `negate(x)` returning `-x`. No input validation
beyond what JavaScript provides natively — non-numeric arguments will produce
`NaN` through standard JS arithmetic coercion, which matches how `percent`
behaves (as confirmed in the plan's open-questions section). The designer
should specify the exact edge-case table and test plan.

## Consequences

- `src/calculator.js` exports `{ add, subtract, percent, negate }`.
- `test/calculator.test.js` gains test cases for `negate` covering the
  acceptance criteria (positive, negative, zero, Infinity, non-numeric).
- No new files, no new dependencies, no changes to existing functions.
- Future operations should follow the same co-location pattern until the
  module warrants decomposition.

## Risks

- **Low — module growth:** Adding a fourth export is unremarkable. The ~8
  export threshold from the `percent-op` ADR still provides headroom. If
  several more operations arrive in quick succession, a future ADR should
  evaluate module decomposition.
- **Negligible — unary precedent:** `negate` is the first unary operation.
  If many unary operations follow, grouping by arity may make sense, but that
  decision belongs to a future ADR when the forcing function exists.

## References

- Planning artifact: `docs/plans/negate.md`
- Prior architecture decision: `docs/architecture/percent-op.md`
- Project conventions: `CLAUDE.md`
