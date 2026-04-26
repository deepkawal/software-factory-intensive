# Percent Operation Work Package

## Goal

Add a `percent(whole, fraction)` function to the calculator that returns
`whole * fraction / 100`. This extends the existing arithmetic module with a
commonly needed percentage calculation.

## User Stories

- As a user, I can call `percent(200, 15)` and receive `30`, so I can compute
  15% of 200 without manual arithmetic.
- As a user, I receive correct results for edge cases such as zero values and
  fractional inputs, so I can trust the function for real-world use.

## Acceptance Criteria

1. `percent(whole, fraction)` is exported from `src/calculator.js`.
2. The function returns `whole * fraction / 100`.
3. `percent(200, 15)` returns `30`.
4. `percent(0, 50)` returns `0`.
5. `percent(100, 0)` returns `0`.
6. `percent(99.99, 50)` returns `49.995`.
7. A matching test file (or additions to `test/calculator.test.js`) covers at
   least the four cases above.
8. `node --test` passes with zero failures.
9. No new dependencies are introduced.

## Scope Boundary

**In scope:**
- Adding the `percent` function to `src/calculator.js`.
- Adding tests for `percent` to the existing test file.
- Exporting `percent` alongside `add` and `subtract`.

**Out of scope:**
- Rounding or formatting helpers.
- Percentage-change or percentage-difference functions.
- Any changes to `add` or `subtract`.

## Dependencies

- None beyond what already exists. The project has zero dependencies and the
  new function is a pure arithmetic operation.

## Open Questions

- None. The request is fully specified.

## Handoff

- **Architect:** Decide whether `percent` belongs in `src/calculator.js` or in
  a new module (e.g., `src/percent.js`). The existing pattern is a single
  module; evaluate whether that should continue or split.
- **Designer:** Specify input-validation behavior — should the function throw
  on non-numeric inputs, return `NaN`, or silently coerce? Document the edge
  cases the test suite must cover.
