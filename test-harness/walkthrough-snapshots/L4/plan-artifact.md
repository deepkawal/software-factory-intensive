# Clamp Operation Work Package

## Goal

Add a `clamp(x, lo, hi)` function to the calculator project that returns `x`
bounded to the interval `[lo, hi]`. If `x < lo` it returns `lo`; if `x > hi` it
returns `hi`; otherwise it returns `x`.

## User Stories

- As a caller, I want `clamp(x, lo, hi)` so I can constrain a value to a given
  range in a single call instead of nesting `Math.min` / `Math.max`.
- As a caller, I expect `clamp` to behave predictably when `lo > hi` (the
  function should either swap the bounds or signal an error).

## Acceptance Criteria

1. `clamp(5, 1, 10)` returns `5` (value within range).
2. `clamp(-3, 0, 10)` returns `0` (value below lower bound).
3. `clamp(15, 0, 10)` returns `10` (value above upper bound).
4. `clamp(0, 0, 0)` returns `0` (all equal edge case).
5. `clamp` is exported from `src/calculator.js` via `module.exports`.
6. At least one happy-path test and edge-case tests exist in
   `test/calculator.test.js`.
7. All existing tests continue to pass.

## Scope Boundary

- **In scope:** the `clamp` function, its export, and its tests.
- **Out of scope:** new files, new dependencies, CLI changes, documentation
  beyond the standard workflow artifacts.

## Dependencies

- None beyond the existing `src/calculator.js` and `test/calculator.test.js`.

## Open Questions

1. What should `clamp` do when `lo > hi`? Options: swap bounds silently, throw a
   `RangeError`, or leave behavior undefined. The architect should decide.
2. Should `clamp` validate that all arguments are numbers, or trust the caller
   (consistent with how `add` and `subtract` behave today)?

## Handoff

The architect should resolve:
- Bounds-inversion behavior (`lo > hi`).
- Input validation strategy (throw vs. trust caller).

The designer should specify:
- Exact function signature and return-type contract.
- Edge-case behavior table (NaN, Infinity, non-numeric inputs if validation is
  chosen).
- Test plan covering each acceptance criterion plus the decided edge cases.
