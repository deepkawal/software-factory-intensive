# Modulo Operation Architecture

## Context

The calculator module (`src/calculator.js`) exports three pure functions: `add`,
`subtract`, and `clamp`. The request is to add `mod(a, b)` — a modulo operation
that returns `a % b`. The planner artifact defines acceptance criteria covering
seven cases including division-by-zero, and raises two handoff questions: the
error type for `mod(a, 0)` and whether `mod` belongs in the existing module or a
separate file.

## Options Considered

### Option A: Inline in `src/calculator.js`, RangeError for division by zero

Add `mod` to the existing module. Throw a `RangeError` when `b === 0`, matching
the error type that `clamp` uses for its invalid-bounds case. No type guards on
inputs.

| Dimension      | Assessment |
|----------------|------------|
| Consistency    | High — same module, same error class as `clamp`, same no-type-guard policy as `add`/`subtract` |
| Simplicity     | High — three lines of logic plus the guard |
| Discoverability | One import path for all calculator operations |
| Error semantics | `RangeError` signals "value outside allowable set" — zero is outside the set of valid divisors |

### Option B: Inline in `src/calculator.js`, TypeError for division by zero

Same placement, but throw `TypeError` instead, arguing that zero is an invalid
type of divisor rather than an out-of-range value.

| Dimension      | Assessment |
|----------------|------------|
| Consistency    | Lower — introduces a second error class into the module |
| Semantic fit   | Arguable — `TypeError` conventionally means wrong type, not wrong value; zero is a valid number |
| Caller impact  | Consumers catching `RangeError` from `clamp` would now need a second catch path |

### Option C: Separate `src/mod.js` module

Place `mod` in its own file with its own test file `test/mod.test.js`.

| Dimension      | Assessment |
|----------------|------------|
| Modularity     | Higher — independent unit with own test surface |
| Consistency    | Breaks the single-module pattern; planner explicitly scopes `mod` to `calculator.js` |
| Overhead       | Extra file, extra import path — disproportionate for a one-function module in a project of this size |

## Decision

**Option A** — add `mod` to `src/calculator.js` with a `RangeError` guard for
`b === 0`, no type guards, using JavaScript's native `%` operator.

Rationale:

1. **Consistency with `clamp`**: The only precedent for an error in this module
   is `clamp`'s `RangeError` for `lo > hi`. Using `RangeError` for division by
   zero keeps a single error class across the module. Zero is not in the
   allowable range of divisors — `RangeError` fits semantically.
2. **Consistency with existing functions**: `add` and `subtract` perform no type
   validation. `mod` should follow the same convention. Type guards are a
   cross-cutting concern to be addressed uniformly if ever needed.
3. **Scope alignment**: The planner scoped `mod` to the calculator module. A
   separate file contradicts the plan and adds structure disproportionate to the
   change.
4. **Operator semantics**: JavaScript's `%` already implements the truncated
   remainder — `mod(-10, 3)` returns `-1`, `mod(10, -3)` returns `1`. No custom
   logic is needed beyond the zero guard. The acceptance criteria explicitly
   follow JS `%` semantics, so wrapping the native operator is sufficient.
5. **Tests**: Place tests in `calculator.test.js` per the one-test-file-per-source
   convention. The seven acceptance criteria map directly to seven test cases in
   a single `describe` block.

## Consequences

- `mod` is exported alongside `add`, `subtract`, and `clamp` from the same
  module — no import-path changes for consumers.
- `mod(a, 0)` throws `RangeError` with a descriptive message including the
  dividend value for debuggability, e.g., `"Cannot compute mod(10, 0): division by zero"`.
- Non-numeric inputs will produce `NaN` silently, consistent with the rest of
  the module.
- Tests in `calculator.test.js` grow by one `describe` block with seven cases.

## Risks

- **NaN propagation**: Callers passing strings or `undefined` get `NaN` instead
  of an error. Mitigated by the project's convention of trusting callers; `add`,
  `subtract`, and `clamp` behave identically.
- **Truncated vs. floored remainder**: JavaScript `%` returns a truncated
  remainder (sign matches the dividend), not a floored remainder (sign matches
  the divisor). Callers expecting Python-style `%` behavior will get different
  results for negative operands. Mitigated by the acceptance criteria explicitly
  specifying JS `%` semantics, and by the planner declaring floored-remainder
  behavior out of scope.

## References

- Planning artifact: `docs/plans/mod-operation.md`
- Architecture precedent: `docs/architecture/clamp.md`
- Source module: `src/calculator.js`
- Project conventions: `CLAUDE.md` (Conventions, Artifact content requirements)
