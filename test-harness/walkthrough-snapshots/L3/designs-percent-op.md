# Percent Operation Design

## Interface

Add `percent` to `src/calculator.js` alongside `add` and `subtract`.

```js
function percent(whole, fraction) { ... }

module.exports = { add, subtract, percent };
```

**Parameters:**

| Name       | Type   | Description                          |
|------------|--------|--------------------------------------|
| `whole`    | number | The base value                       |
| `fraction` | number | The percentage to apply (e.g. 15 for 15%) |

**Returns:** `number` — the result of `whole * fraction / 100`.

**Import:** Consumers destructure from the existing module:

```js
const { percent } = require('../src/calculator');
```

## Behavior

- `percent(200, 15)` returns `30` (15% of 200).
- `percent(0, 50)` returns `0` (any percentage of zero is zero).
- `percent(100, 0)` returns `0` (0% of anything is zero).
- `percent(99.99, 50)` returns `49.995` (fractional inputs work correctly).
- `percent(-200, 25)` returns `-50` (negative values propagate naturally).
- `percent(100, 100)` returns `100` (100% returns the whole).
- `percent(100, 200)` returns `200` (fractions above 100 are valid).

**No input validation.** Non-numeric arguments produce `NaN` via standard JS
arithmetic, matching the existing behavior of `add` and `subtract`. The
architect confirmed this approach — no type checks, no coercion, no throws.

## Edge Cases

| Input                        | Expected | Reason                                   |
|------------------------------|----------|------------------------------------------|
| `percent(200, 15)`          | `30`     | Standard percentage calculation          |
| `percent(0, 50)`            | `0`      | Zero whole                               |
| `percent(100, 0)`           | `0`      | Zero fraction                            |
| `percent(99.99, 50)`        | `49.995` | Fractional inputs (exactly representable)|
| `percent(-200, 25)`         | `-50`    | Negative whole propagates                |
| `percent(100, -10)`         | `-10`    | Negative fraction propagates             |
| `percent(100, 200)`         | `200`    | Fraction > 100 is valid                  |
| `percent('a', 10)`          | `NaN`    | Non-numeric whole, no validation         |
| `percent(100, undefined)`   | `NaN`    | Missing argument, no validation          |
| `percent()`                 | `NaN`    | Both args undefined, no validation       |

No IEEE 754 precision issue arises for the acceptance-criteria values. The
architecture ADR notes this is acceptable and defers rounding to a future ADR if
precision guarantees are ever needed.

## Test Plan

Add tests to `test/calculator.test.js`. Import `percent` in the existing
destructuring line. Each test follows the project's one-assertion-per-test
pattern using `node:test` and `node:assert/strict`.

**Required tests (from acceptance criteria):**

1. `percent(200, 15)` equals `30` — standard case.
2. `percent(0, 50)` equals `0` — zero whole.
3. `percent(100, 0)` equals `0` — zero fraction.
4. `percent(99.99, 50)` equals `49.995` — fractional inputs.

**Recommended additional tests:**

5. `percent(-200, 25)` equals `-50` — negative input.
6. `percent('a', 10)` is `NaN` — non-numeric input returns NaN.

All tests must pass via `node --test`.

## Build Notes

**Files to modify:**

- `src/calculator.js` — Add the `percent` function and include it in
  `module.exports`. Place it after `subtract`, before the exports line.
- `test/calculator.test.js` — Add `percent` to the destructured import on
  line 3. Add test cases after the existing `subtract` test.

**Files to inspect (no changes expected):**

- `package.json` — Verify `"test": "node --test"` is the test script (it is).
- `CLAUDE.md` — Confirms conventions (CommonJS, `node:test`, one test file per
  source file).

**Branch:** Create a `feature/percent-op` branch per CLAUDE.md conventions.

**No new files, no new dependencies.**

## References

- Plan: `docs/plans/percent-op.md`
- Architecture: `docs/architecture/percent-op.md`
- Source: `src/calculator.js`
- Tests: `test/calculator.test.js`
