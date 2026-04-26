# Negate Operation Work Package

## Goal

Add a `negate(x)` function to the calculator project that returns `-x`, giving
users a unary sign-flip operation alongside the existing binary arithmetic
functions (`add`, `subtract`, `percent`).

## User Stories

- As a caller, I can invoke `negate(x)` and receive `-x` so that I can flip the
  sign of a number without constructing a subtraction from zero.
- As a caller, I receive `NaN` when I pass a non-numeric value to `negate` so
  that error behavior is consistent with `percent`.

## Acceptance Criteria

1. `negate(5)` returns `-5`.
2. `negate(-3)` returns `3`.
3. `negate(0)` returns `-0` (or `0`; either is acceptable since `0 === -0` in JS).
4. `negate(Infinity)` returns `-Infinity`.
5. `negate('a')` returns `NaN`.
6. The function is exported from `src/calculator.js` via `module.exports`.
7. At least one happy-path test and one edge-case test exist in
   `test/calculator.test.js`.
8. `node --test` passes with no failures.

## Scope Boundary

- **In scope:** one new pure function, its export, and its tests.
- **Out of scope:** new source files, CLI changes, class refactors, changes to
  existing functions, or any other unary operations beyond `negate`.

## Dependencies

- None. The function is self-contained and has no external or internal
  dependencies beyond the existing `src/calculator.js` module.

## Open Questions

- Should `negate` coerce string-numeric inputs (e.g., `negate("5")` → `-5`) or
  treat all non-number inputs as `NaN`? Assumed: follow the `percent` precedent
  and rely on JS arithmetic coercion (strings that look like numbers will
  coerce; non-numeric strings yield `NaN`).

## Handoff

- **Architect:** Decide whether `negate` belongs in `calculator.js` or warrants
  a separate module (given the project's "small pure functions" convention and
  the fact that this is a single one-liner, co-location is the expected choice).
- **Designer:** Specify exact function signature, parameter validation behavior,
  edge-case table, and test plan covering acceptance criteria above.
