# Clamp Operation Design

## Interface

```js
function clamp(x, lo, hi)
```

- **Parameters:**
  - `x` (number) — the value to clamp.
  - `lo` (number) — the lower bound (inclusive).
  - `hi` (number) — the upper bound (inclusive).
- **Returns:** `number` — `x` if `lo <= x <= hi`, otherwise the nearer bound.
- **Throws:** `RangeError` with message `"lo must be <= hi"` when `lo > hi`.
- **Export:** added to the existing `module.exports` object in `src/calculator.js`.

No type validation is performed on arguments; this is consistent with `add` and
`subtract`, which trust the caller to pass numbers.

## Behavior

1. If `lo > hi`, throw `new RangeError("lo must be <= hi")`.
2. If `x < lo`, return `lo`.
3. If `x > hi`, return `hi`.
4. Otherwise return `x`.

The bounds check (step 1) runs before the clamp logic so that an inverted-range
bug is never masked by a coincidentally valid result.

Implementation should use `Math.max(lo, Math.min(x, hi))` after the bounds
guard, or equivalent conditional logic.

## Edge Cases

| Input | Expected | Rationale |
|---|---|---|
| `clamp(5, 1, 10)` | `5` | Value within range — returned unchanged |
| `clamp(-3, 0, 10)` | `0` | Below lower bound — clamped up |
| `clamp(15, 0, 10)` | `10` | Above upper bound — clamped down |
| `clamp(0, 0, 0)` | `0` | All arguments equal — valid, returns the value |
| `clamp(5, 5, 5)` | `5` | Equal bounds — not inverted, returns the bound |
| `clamp(5, 10, 1)` | throws `RangeError` | Inverted bounds — fail-fast per architecture decision |
| `clamp(-Infinity, 0, 10)` | `0` | -Infinity is below lo |
| `clamp(Infinity, 0, 10)` | `10` | Infinity is above hi |
| `clamp(NaN, 0, 10)` | `NaN` | No type validation; `Math.min`/`Math.max` propagate NaN — accepted project-wide |

## Test Plan

All tests go in `test/calculator.test.js` alongside the existing `add` and
`subtract` tests, using `node:test` and `node:assert/strict`.

| # | Test name | Assertion |
|---|---|---|
| 1 | `clamp returns x when within range` | `clamp(5, 1, 10) === 5` |
| 2 | `clamp returns lo when x is below range` | `clamp(-3, 0, 10) === 0` |
| 3 | `clamp returns hi when x is above range` | `clamp(15, 0, 10) === 10` |
| 4 | `clamp returns value when all arguments are equal` | `clamp(0, 0, 0) === 0` |
| 5 | `clamp throws RangeError when lo > hi` | `assert.throws(() => clamp(5, 10, 1), RangeError)` |
| 6 | `clamp returns lo for equal bounds` | `clamp(5, 3, 3) === 3` |

Tests 1–4 cover the acceptance criteria from the plan. Test 5 covers the
architecture decision (Option A). Test 6 confirms equal bounds are not treated
as inverted.

Existing `add` and `subtract` tests must continue to pass.

## Build Notes

Files to inspect or change:

- **`src/calculator.js`** — Add the `clamp` function after `subtract`. Add
  `clamp` to the `module.exports` object.
- **`test/calculator.test.js`** — Import `clamp` in the destructuring require
  on line 3. Add the six test cases listed above after the existing tests.

No new files, dependencies, or build configuration changes are needed.

## References

- Plan: `docs/plans/clamp.md`
- Architecture: `docs/architecture/clamp.md`
- Project conventions: `CLAUDE.md`
