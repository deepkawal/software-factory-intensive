# Clamp Operation Design

## Interface

Export a new `clamp` function from `src/calculator.js`:

```js
function clamp(x, lo, hi)
```

- **Parameters**: three `Number` arguments — the value to clamp, the lower
  bound, and the upper bound.
- **Returns**: `Number` — `lo` if `x < lo`, `hi` if `x > hi`, otherwise `x`.
- **Throws**: `RangeError` when `lo > hi`. The message must include the actual
  `lo` and `hi` values (e.g., `"lo (5) must not exceed hi (3)"`).
- **Export**: add `clamp` to the existing `module.exports` object alongside
  `add` and `subtract`.

No type guards on arguments — consistent with `add` and `subtract`.

## Behavior

1. If `lo > hi`, throw `RangeError` before any clamping logic runs.
2. Return `Math.min(Math.max(x, lo), hi)`.
3. When `lo === hi`, the function returns `lo` regardless of `x` (degenerate
   single-point range).
4. Non-numeric inputs propagate as `NaN` — no special handling, matching the
   existing module contract.

## Edge Cases

| Input | Expected | Notes |
|---|---|---|
| `clamp(5, 1, 10)` | `5` | Within range |
| `clamp(-3, 0, 10)` | `0` | Below lower bound |
| `clamp(15, 0, 10)` | `10` | Above upper bound |
| `clamp(0, 0, 0)` | `0` | Degenerate single-point range |
| `clamp(5, 10, 3)` | throws `RangeError` | Invalid bounds |
| `clamp(5, 5, 5)` | `5` | All three equal |
| `clamp(-Infinity, 0, 10)` | `0` | Negative infinity clamped to lo |
| `clamp(Infinity, 0, 10)` | `10` | Positive infinity clamped to hi |
| `clamp("a", 0, 10)` | `NaN` | Non-numeric propagates silently |

## Test Plan

Add a `describe('clamp', ...)` block to `test/calculator.test.js`. Import
`clamp` alongside `add` and `subtract` from `../src/calculator`. Use
`node:test` and `node:assert/strict` matching the existing test style.

Tests (one `test()` call each):

1. **returns value when within range** — `clamp(5, 1, 10)` → `5`
2. **returns lo when value is below range** — `clamp(-3, 0, 10)` → `0`
3. **returns hi when value is above range** — `clamp(15, 0, 10)` → `10`
4. **returns lo for single-point range** — `clamp(42, 0, 0)` → `0`
5. **throws RangeError when lo > hi** — `assert.throws(() => clamp(5, 10, 3), RangeError)`
6. **existing add and subtract tests still pass** — no changes to existing test cases.

## Build Notes

Files to modify:

- **`src/calculator.js`** — Add the `clamp` function above the `module.exports`
  line. Add `clamp` to the exports object. Do not change `add` or `subtract`.
- **`test/calculator.test.js`** — Add `clamp` to the destructured import on
  line 3. Add a `describe('clamp', ...)` block after the existing `subtract`
  test (after line 11). Do not modify existing tests.

Files to leave unchanged:

- `package.json` — no new dependencies or script changes needed.

## References

- Plan: `docs/plans/clamp.md`
- Architecture decision: `docs/architecture/clamp.md`
- Source module: `src/calculator.js`
- Test file: `test/calculator.test.js`
