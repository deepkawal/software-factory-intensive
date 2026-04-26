# Percent Operation Design

## Interface

```js
function percent(whole, fraction) {
  return whole * fraction / 100;
}
```

- **Signature:** `percent(whole, fraction)` where both arguments are numbers.
- **Return value:** `whole * fraction / 100` (a number).
- **Export:** Added to the existing `module.exports` object in `src/calculator.js`
  alongside `add` and `subtract`.

```js
module.exports = { add, subtract, percent };
```

## Behavior

| Input                  | Output | Rationale                        |
|------------------------|--------|----------------------------------|
| `percent(200, 15)`     | `30`   | Happy path: 15% of 200          |
| `percent(0, 50)`       | `0`    | Zero whole yields zero           |
| `percent(100, 0)`      | `0`    | Zero fraction yields zero        |
| `percent(50, 100)`     | `50`   | 100% returns the whole           |
| `percent(-200, 10)`    | `-20`  | Negative whole propagates sign   |
| `percent(200, -10)`    | `-20`  | Negative fraction propagates sign|
| `percent(-200, -10)`   | `20`   | Double negative yields positive  |
| `percent(1, 3)`        | `0.03` | Native JS floating-point result  |
| `percent(1000000, 50)` | `500000` | Large values work normally     |

The function relies on native JavaScript arithmetic. No rounding, clamping, or
type coercion is applied. This matches the behavior of `add` and `subtract`,
which are also thin wrappers around arithmetic operators with no input
validation.

## Edge Cases

1. **Floating-point results** — `percent(1, 3)` returns `0.03`. No rounding is
   performed; consumers handle precision if needed. This is explicitly out of
   scope per the plan.
2. **Non-numeric arguments** — No validation. Passing strings or undefined
   produces `NaN`, consistent with `add` and `subtract`. Input validation is
   out of scope.
3. **Very large numbers** — Follows standard IEEE 754 behavior. No overflow
   protection.
4. **Both arguments negative** — Returns a positive number per standard
   multiplication rules. This is correct and needs no special handling.

## Test Plan

Add a `describe`-style grouping (using `node:test`) to `test/calculator.test.js`.
Import `percent` from `../src/calculator`.

```js
const { add, subtract, percent } = require('../src/calculator');
```

Tests to add (each is a single `test()` call with `assert.equal` or
`assert.strictEqual`):

1. **Happy path:** `percent(200, 15)` equals `30`.
2. **Zero whole:** `percent(0, 50)` equals `0`.
3. **Zero fraction:** `percent(100, 0)` equals `0`.
4. **Full 100%:** `percent(50, 100)` equals `50`.
5. **Negative whole:** `percent(-200, 10)` equals `-20`.
6. **Negative fraction:** `percent(200, -10)` equals `-20`.
7. **Both negative:** `percent(-200, -10)` equals `20`.
8. **Fractional result:** `percent(1, 3)` equals `0.03`.

Follow the existing test style: flat `test()` calls with `assert.equal`, one
assertion per test, descriptive string labels. Run with `node --test`.

## Build Notes

Files to modify:

- **`src/calculator.js`** — Add the `percent` function (3 lines) and include it
  in `module.exports`. Place after `subtract`, before the exports line.
- **`test/calculator.test.js`** — Add `percent` to the destructured import on
  line 3. Add 8 new `test()` calls after the existing `subtract` test (line 11).

No new files, dependencies, or build configuration changes.

## References

- Plan: `docs/plans/percent.md`
- Architecture: `docs/architecture/percent.md`
- Source: `src/calculator.js`
- Tests: `test/calculator.test.js`
