# Negate Operation Design

## Interface

Add `negate` to `src/calculator.js` alongside `add`, `subtract`, and `percent`.

```js
function negate(x) { ... }

module.exports = { add, subtract, percent, negate };
```

**Parameters:**

| Name | Type   | Description                     |
|------|--------|---------------------------------|
| `x`  | number | The value whose sign to flip    |

**Returns:** `number` — the result of `-x`.

**Import:** Consumers destructure from the existing module:

```js
const { negate } = require('../src/calculator');
```

## Behavior

- `negate(5)` returns `-5` (positive becomes negative).
- `negate(-3)` returns `3` (negative becomes positive).
- `negate(0)` returns `-0` (IEEE 754 negative zero; `0 === -0` in JS so both are acceptable).
- `negate(Infinity)` returns `-Infinity`.
- `negate(-Infinity)` returns `Infinity`.
- `negate("5")` returns `-5` (string-numeric coercion via JS unary negation).
- `negate('a')` returns `NaN` (non-numeric string).

**No input validation.** Non-numeric arguments produce `NaN` via standard JS
arithmetic coercion, matching the established behavior of `percent`. The
architecture ADR confirmed this approach — no type checks, no explicit
coercion, no throws. JS unary negation (`-x`) handles coercion natively.

## Edge Cases

| Input               | Expected      | Reason                                      |
|---------------------|---------------|---------------------------------------------|
| `negate(5)`         | `-5`          | Standard positive input                     |
| `negate(-3)`        | `3`           | Double negation restores positive            |
| `negate(0)`         | `-0`          | IEEE 754 negative zero; `0 === -0` in JS    |
| `negate(Infinity)`  | `-Infinity`   | Infinity sign-flips correctly                |
| `negate(-Infinity)` | `Infinity`    | Negative infinity sign-flips correctly       |
| `negate(NaN)`       | `NaN`         | NaN propagates through negation              |
| `negate("5")`       | `-5`          | String-numeric coerces then negates          |
| `negate('a')`       | `NaN`         | Non-numeric string yields NaN               |
| `negate(undefined)` | `NaN`         | Missing argument, no validation              |
| `negate()`          | `NaN`         | No argument supplied, `x` is undefined       |

No precision concerns — unary negation flips the sign bit without arithmetic
rounding.

## Test Plan

Add tests to `test/calculator.test.js`. Add `negate` to the existing
destructured import on line 3. Each test follows the project's
one-assertion-per-test pattern using `node:test` and `node:assert/strict`.

**Required tests (from acceptance criteria):**

1. `negate(5)` equals `-5` — positive input.
2. `negate(-3)` equals `3` — negative input.
3. `negate(0)` — result is `0` or `-0` (assert `Object.is(negate(0), -0)` or simply `assert.equal(negate(0), 0)` since both are correct per the plan).
4. `negate(Infinity)` equals `-Infinity` — infinity edge case.
5. `negate('a')` is `NaN` — non-numeric input (use `Number.isNaN`).

**Recommended additional test:**

6. `negate(-Infinity)` equals `Infinity` — symmetric infinity case.

All tests must pass via `node --test`.

## Build Notes

**Files to modify:**

- `src/calculator.js` — Add the `negate` function after `percent` (line 11),
  before the `module.exports` line. Add `negate` to the `module.exports` object
  on line 13.
- `test/calculator.test.js` — Add `negate` to the destructured import on
  line 3. Add test cases after the existing `percent` tests (after line 35).

**Files to inspect (no changes expected):**

- `package.json` — Verify `"test": "node --test"` is the test script.
- `CLAUDE.md` — Confirms conventions (CommonJS, `node:test`, one test file per
  source file).

**Branch:** Create a `feature/negate` branch per CLAUDE.md conventions.

**No new files, no new dependencies.**

## References

- Plan: `docs/plans/negate.md`
- Architecture: `docs/architecture/negate.md`
- Prior design precedent: `docs/designs/percent-op.md`
- Source: `src/calculator.js`
- Tests: `test/calculator.test.js`
