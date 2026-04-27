# Modulo Operation Work Package

## Goal

Add a `mod(a, b)` function to the calculator module that returns `a % b`. This
extends the project's pure-function calculator with a standard arithmetic
operation.

## User Stories

- As a caller, I can pass `mod(a, b)` and receive the remainder of dividing `a`
  by `b`, matching JavaScript's `%` operator behavior.
- As a caller, I receive a clear error when `b` is zero so I am not silently
  given `NaN`.

## Acceptance Criteria

1. `mod(10, 3)` returns `1` (basic positive case).
2. `mod(10, 5)` returns `0` (evenly divisible).
3. `mod(-7, 3)` returns `-1` (negative dividend follows JS `%` semantics).
4. `mod(7, -3)` returns `1` (negative divisor follows JS `%` semantics).
5. `mod(0, 5)` returns `0` (zero dividend).
6. `mod(a, 0)` throws a `RangeError` with a descriptive message when the divisor
   is zero.
7. The function is exported from `src/calculator.js` alongside `add`, `subtract`,
   and `clamp`.
8. A matching test block covers all criteria above using `node:test` and
   `node:assert/strict`.
9. All existing tests continue to pass.

## Scope Boundary

**In scope:**
- The `mod` function implementation in `src/calculator.js`.
- Tests for `mod` in `test/calculator.test.js`.

**Out of scope:**
- A "mathematical modulo" variant (always-positive result) — only the JS `%`
  remainder behavior is requested.
- New source files — `mod` lives in the existing calculator module.
- Input type validation beyond the division-by-zero check.
- TypeScript, build tooling, or dependency changes.

## Dependencies

- None. The implementation uses only JavaScript's built-in `%` operator and
  standard `RangeError`.

## Open Questions

1. **Remainder vs. mathematical modulo** — JavaScript `%` can return negative
   values for negative dividends (e.g. `-7 % 3 === -1`). The request says
   "returns a%b" so we follow JS semantics. The architect or designer should
   confirm this is the desired behavior, or decide whether to also offer a
   true-modulo variant.
2. **Non-numeric inputs** — The request does not specify behavior for
   non-numeric arguments. Assume no input validation beyond the `b === 0` check;
   the architect or designer should decide whether to add type guards.

## Handoff

The architect and designer should resolve:

- Whether `mod` should follow JS remainder semantics (`%`) or true mathematical
  modulo (always non-negative). The plan assumes JS `%` per the request wording.
- Whether to throw `RangeError` for division by zero (recommended, consistent
  with `clamp`'s error pattern) or return `NaN` / `Infinity`.
- Whether non-numeric arguments warrant explicit validation or are left to
  callers.
