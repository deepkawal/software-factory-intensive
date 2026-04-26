# Percent Operation Work Package

## Goal

Add a `percent(whole, fraction)` function to the calculator that returns
`whole * fraction / 100`. This extends the calculator's arithmetic operations
with a convenience function for percentage calculations.

## User Stories

- As a user, I want to call `percent(200, 15)` and get `30`, so I can compute
  15% of 200 without manually dividing by 100.
- As a user, I want `percent` to follow the same conventions as `add` and
  `subtract` — a pure function exported from `src/calculator.js`.

## Acceptance Criteria

1. `percent(whole, fraction)` is exported from `src/calculator.js`.
2. `percent(200, 15)` returns `30`.
3. `percent(0, 50)` returns `0` (zero whole).
4. `percent(100, 0)` returns `0` (zero fraction).
5. `percent(50, 100)` returns `50` (100% of whole).
6. Negative inputs are handled correctly: `percent(-200, 10)` returns `-20`.
7. A matching test file entry exists in `test/calculator.test.js` with at least
   one happy-path test and the edge cases above.
8. `node --test` passes with no failures.

## Scope Boundary

- **In scope:** One new pure function, exported alongside existing operations;
  corresponding tests.
- **Out of scope:** Input validation (non-numeric args), rounding behaviour,
  formatting output as a string with `%`, new source files, build changes,
  or dependency additions.

## Dependencies

- `src/calculator.js` — the function will be added here.
- `test/calculator.test.js` — tests will be added here.
- No external dependencies.

## Open Questions

- Should `percent` live in `src/calculator.js` alongside `add`/`subtract`, or
  in a separate module? **Assumption:** same file, matching the existing
  pattern of small pure functions in one module. The architect should confirm.

## Handoff

- **Architect:** Confirm that adding `percent` to `src/calculator.js` (vs. a
  new file) is the right module-level decision given the project's growth
  trajectory.
- **Designer:** Specify the exact function signature, edge-case behaviour for
  floating-point results (e.g., `percent(1, 3)` → `0.03`), and the full test
  plan covering the acceptance criteria above.
