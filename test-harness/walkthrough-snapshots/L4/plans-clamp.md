# Clamp Operation Work Package

## Goal

Add a `clamp(x, lo, hi)` function to the calculator module that returns `x`
bounded to the range `[lo, hi]`. This extends the project's pure-function
calculator with a common numerical utility.

## User Stories

- As a caller, I can pass `clamp(x, lo, hi)` and receive `lo` when `x < lo`,
  `hi` when `x > hi`, or `x` when it is already within bounds.
- As a caller, I receive a clear error when `lo > hi` so I am not silently given
  a nonsensical result.

## Acceptance Criteria

1. `clamp(5, 1, 10)` returns `5` (value within range).
2. `clamp(-3, 0, 10)` returns `0` (value below lower bound).
3. `clamp(15, 0, 10)` returns `10` (value above upper bound).
4. `clamp(0, 0, 0)` returns `0` (degenerate single-point range).
5. `clamp(x, lo, hi)` throws a `RangeError` when `lo > hi`.
6. The function is exported from `src/calculator.js` alongside `add` and
   `subtract`.
7. A matching test file or test block covers all criteria above using `node:test`
   and `node:assert/strict`.
8. All existing tests continue to pass.

## Scope Boundary

**In scope:**
- The `clamp` function implementation in `src/calculator.js`.
- Tests for `clamp` in `test/calculator.test.js`.

**Out of scope:**
- New source files — `clamp` lives in the existing calculator module.
- Generalised min/max helpers — `Math.min`/`Math.max` are sufficient inline.
- TypeScript, build tooling, or dependency changes.

## Dependencies

- None. The implementation uses only built-in `Math.min` / `Math.max` and
  standard `RangeError`.

## Open Questions

1. **Error behavior for non-numeric inputs** — The request does not specify
   behavior when `x`, `lo`, or `hi` are non-numeric. Assume no input validation
   beyond the `lo > hi` check for now; the architect or designer should decide
   whether to add type guards.

## Handoff

The architect and designer should resolve:

- Whether the `lo > hi` error should be a `RangeError` (recommended) or a
  different error type.
- Whether to validate that all three arguments are finite numbers, or leave that
  to callers.
- Whether the new tests should be added to the existing
  `test/calculator.test.js` or placed in a separate `test/clamp.test.js` — the
  project convention of "one test file per src file" suggests keeping them in
  `calculator.test.js`, but a separate file is viable if the test count grows.
