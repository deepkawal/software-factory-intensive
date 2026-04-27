# Clamp Operation Architecture

## Context

The calculator module (`src/calculator.js`) currently exports two pure functions:
`add` and `subtract`. The request is to add `clamp(x, lo, hi)` — a bounded-range
utility that returns `x` constrained to `[lo, hi]`. The planner artifact defines
acceptance criteria, user stories, and three open questions that this architecture
decision resolves: error type for invalid bounds, input-type validation policy,
and test file placement.

## Options Considered

### Option A: Inline in `src/calculator.js`, no type guards

Add `clamp` directly to the existing module. Validate only the `lo > hi`
invariant with a `RangeError`. Do not validate argument types.

| Dimension        | Assessment |
|------------------|------------|
| Simplicity       | High — one file, one export block, minimal code |
| Consistency      | Matches `add`/`subtract` which perform no type checking |
| Error surface    | Callers passing non-numeric values get silent `NaN` propagation |
| Test placement   | Tests go in existing `calculator.test.js` per one-file-per-src convention |

### Option B: Inline in `src/calculator.js`, with type guards on all arguments

Same placement, but add `typeof` checks on `x`, `lo`, and `hi`, throwing
`TypeError` for non-finite-number inputs before the bounds check.

| Dimension        | Assessment |
|------------------|------------|
| Robustness       | Higher — catches misuse at the call site |
| Consistency      | Breaks parity with `add`/`subtract` which accept anything |
| Code size        | Adds 3–5 lines of guard logic |
| Maintenance cost | Every future function would need the same guards or the module feels inconsistent |

### Option C: Separate `src/clamp.js` module

Place `clamp` in its own file with its own test file `test/clamp.test.js`.

| Dimension        | Assessment |
|------------------|------------|
| Modularity       | Higher — independent unit |
| Consistency      | Breaks the current single-module pattern; the plan explicitly scopes `clamp` to the calculator module |
| Overhead         | Extra file, extra import path, extra test file — disproportionate for one function |

## Decision

**Option A** — add `clamp` to `src/calculator.js` with only the `lo > hi`
bounds check, no type guards.

Rationale:

1. **Consistency**: `add` and `subtract` do not validate argument types. Adding
   guards only to `clamp` creates an inconsistent contract within the module.
   If type validation is desired later, it should be added uniformly to all
   exports in a separate effort.
2. **Scope**: The planner scoped `clamp` to the existing calculator module. A
   new file contradicts the plan and adds unnecessary structure for one function.
3. **Error type**: `RangeError` is the correct choice for `lo > hi` — it signals
   a value outside an allowable range, which matches the semantic exactly. The
   message should include the actual `lo` and `hi` values for debuggability.
4. **Tests**: Place tests in `calculator.test.js` following the project
   convention of one test file per source file. The five acceptance-criteria
   cases plus the error case fit cleanly in a single `describe` block.

## Consequences

- `clamp` is exported alongside `add` and `subtract` from the same module —
  no import-path changes for consumers.
- Non-numeric inputs will produce `NaN` silently, consistent with the rest of
  the module. This is an acceptable tradeoff given the project's conventions;
  type guards can be revisited as a cross-cutting concern later.
- Tests in `calculator.test.js` will grow by roughly one `describe` block with
  five to six test cases.

## Risks

- **NaN propagation**: Callers passing strings or `undefined` get `NaN` instead
  of an error. Mitigated by the project's convention of trusting callers and the
  fact that `add`/`subtract` behave identically.
- **Boundary precision**: Floating-point edge cases (e.g., `clamp(0.1+0.2, 0.3, 1)`)
  may surprise callers. This is inherent to JavaScript's `Number` type and not
  specific to `clamp`; no mitigation needed beyond documentation.

## References

- Planning artifact: `docs/plans/clamp.md`
- Source module: `src/calculator.js`
- Project conventions: `CLAUDE.md` (Conventions, Artifact content requirements)
