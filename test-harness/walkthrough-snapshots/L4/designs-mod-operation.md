# Modulo Operation Design

## Interface

Export a new `mod` function from `src/calculator.js`:

```js
/**
 * Returns the remainder of dividing a by b.
 * @param {number} a — dividend
 * @param {number} b — divisor (must not be zero)
 * @returns {number} a % b
 * @throws {RangeError} if b is zero
 */
function mod(a, b)
```

- **Parameters**: two `Number` arguments — the dividend and the divisor.
- **Returns**: `Number` — the remainder of `a / b` using JavaScript's native `%`
  operator (truncated remainder; sign matches the dividend).
- **Throws**: `RangeError` when `b === 0`. The message must include the dividend
  value for debuggability (e.g., `"Cannot compute mod(10, 0): division by zero"`).
- **Export**: add `mod` to the existing `module.exports` object alongside `add`,
  `subtract`, and `clamp`.

No type guards on arguments — consistent with the rest of the module.

## Behavior

1. If `b === 0`, throw `RangeError` before computing the remainder.
2. Return `a % b`.
3. Sign of the result matches the sign of `a` (JavaScript truncated remainder
   semantics). `mod(-10, 3)` returns `-1`; `mod(10, -3)` returns `1`.
4. Non-numeric inputs propagate as `NaN` — no special handling, matching the
   existing module contract.

## Edge Cases

| Input | Expected | Notes |
|---|---|---|
| `mod(10, 3)` | `1` | Basic positive case |
| `mod(10, -3)` | `1` | Negative divisor; result sign follows dividend |
| `mod(-10, 3)` | `-1` | Negative dividend; result sign follows dividend |
| `mod(0, 5)` | `0` | Zero dividend |
| `mod(7, 1)` | `0` | Divisor of one always yields zero remainder |
| `mod(10, 0)` | throws `RangeError` | Division by zero |
| `mod(-10, 0)` | throws `RangeError` | Division by zero, negative dividend |
| `mod(10.5, 3)` | `1.5` | Floating-point remainder works natively |
| `mod("a", 3)` | `NaN` | Non-numeric propagates silently |

## Test Plan

Add tests for `mod` to `test/calculator.test.js`. Import `mod` alongside `add`,
`subtract`, and `clamp` from `../src/calculator`. Use `node:test` and
`node:assert/strict` matching the existing test style (flat `test()` calls, not
nested `describe` blocks — matching how the clamp tests were actually written).

Tests (one `test()` call each):

1. **mod returns the remainder of two positive numbers** — `mod(10, 3)` → `1`
2. **mod returns positive remainder when divisor is negative** — `mod(10, -3)` → `1`
3. **mod returns negative remainder when dividend is negative** — `mod(-10, 3)` → `-1`
4. **mod returns zero when dividend is zero** — `mod(0, 5)` → `0`
5. **mod returns zero when divisor is one** — `mod(7, 1)` → `0`
6. **mod throws RangeError when divisor is zero** — `assert.throws(() => mod(10, 0), RangeError)`
7. **existing add, subtract, and clamp tests still pass** — no changes to existing test cases.

## Build Notes

Files to modify:

- **`src/calculator.js`** — Add the `mod` function with JSDoc above the
  `module.exports` line. Add `mod` to the exports object. Use the error message
  format `"Cannot compute mod(${a}, 0): division by zero"` to include the
  dividend for debuggability. Do not change `add`, `subtract`, or `clamp`.
- **`test/calculator.test.js`** — Add `mod` to the destructured import on
  line 3. Add six flat `test()` calls after the existing clamp tests (after
  line 31). Do not modify existing tests.

Files to leave unchanged:

- `package.json` — no new dependencies or script changes needed.
- `docs/plans/mod-operation.md` — upstream artifact, read-only.
- `docs/architecture/mod-operation.md` — upstream artifact, read-only.

## References

- Plan: `docs/plans/mod-operation.md`
- Architecture decision: `docs/architecture/mod-operation.md`
- Clamp design precedent: `docs/designs/clamp.md`
- Source module: `src/calculator.js`
- Test file: `test/calculator.test.js`
