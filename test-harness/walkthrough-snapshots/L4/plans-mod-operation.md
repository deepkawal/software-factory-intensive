# Modulo Operation Work Package

## Goal

Add a `mod(a, b)` function to the calculator library that returns the remainder
of dividing `a` by `b` (i.e., `a % b`), following the same conventions as the
existing `add`, `subtract`, and `clamp` functions.

## User Stories

- As a consumer of the calculator library, I want to compute the remainder of
  integer division so that I can perform modular arithmetic without importing
  another module.
- As a developer, I want `mod` to handle division-by-zero explicitly so that
  callers get a clear error instead of `NaN` or `Infinity`.

## Acceptance Criteria

1. `mod(10, 3)` returns `1`.
2. `mod(10, -3)` returns `1` (follows JavaScript `%` semantics).
3. `mod(-10, 3)` returns `-1` (follows JavaScript `%` semantics).
4. `mod(0, 5)` returns `0`.
5. `mod(7, 1)` returns `0`.
6. `mod(a, 0)` throws a descriptive error (division by zero).
7. The function is exported from `src/calculator.js` via `module.exports`.
8. A corresponding test file or test additions cover at least the cases above.
9. The function has a JSDoc comment per the project review standards.

## Scope Boundary

**In scope:**
- The `mod` function itself in `src/calculator.js`.
- Tests in `test/calculator.test.js`.
- JSDoc on the new export.

**Out of scope:**
- Floating-point modulo edge cases beyond what `%` natively provides.
- A separate `remainder` or `divmod` function.
- Changes to existing functions or test cases.
- Any build or dependency changes.

## Dependencies

- None. The function is self-contained and uses only the built-in `%` operator.

## Open Questions

1. Should `mod` validate that both arguments are numbers (i.e., throw on
   non-numeric input), or rely on JavaScript's implicit coercion? The existing
   functions (`add`, `subtract`) do not validate types. Assumption: follow
   existing convention and skip type validation for now.

## Handoff

The architect should decide:
- Whether the division-by-zero error should be a `RangeError` (consistent with
  `clamp`'s error style) or a different error type.
- Whether `mod` belongs in `calculator.js` alongside the arithmetic functions or
  warrants a separate module (given the current project size, keeping it in
  `calculator.js` is the expected choice).

The designer should specify:
- The exact function signature and JSDoc wording.
- Edge-case behavior table for the test plan.
- Whether negative-operand semantics need explicit documentation beyond "follows
  JS `%`."
