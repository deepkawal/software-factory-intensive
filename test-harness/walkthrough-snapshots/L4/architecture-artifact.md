# Clamp Operation Architecture

## Context

The calculator project exposes pure arithmetic functions (`add`, `subtract`)
from `src/calculator.js` with no input validation and zero dependencies. A new
`clamp(x, lo, hi)` function is requested to constrain a value to the interval
`[lo, hi]`. Two open design questions were flagged by the planner:

1. What happens when `lo > hi` (inverted bounds)?
2. Should `clamp` validate argument types, or trust the caller like `add` and
   `subtract` do?

## Options Considered

### Option A — Throw on inverted bounds; trust caller on types

- `clamp` throws a `RangeError` when `lo > hi`.
- No type checking — consistent with how `add(a, b)` and `subtract(a, b)`
  behave today.
- **Pro:** Fails fast on a likely caller bug (swapped arguments). Keeps the
  type-validation posture uniform across every exported function.
- **Con:** Introduces the project's first thrown exception, which callers must
  handle or let propagate.

### Option B — Silently swap inverted bounds; trust caller on types

- If `lo > hi`, swap them so the call succeeds with the "intended" range.
- No type checking.
- **Pro:** Never throws; every numeric input produces a numeric output.
- **Con:** Masks a probable bug in the caller. A caller passing `clamp(x, 10,
  0)` may not realize the bounds were reversed and could rely on the silent fix
  indefinitely.

### Option C — Add full type validation to clamp

- Validate that all three arguments are finite numbers; throw `TypeError`
  otherwise. Also throw `RangeError` on inverted bounds.
- **Pro:** Strictest safety net.
- **Con:** Inconsistent with `add` and `subtract`, which accept any input
  without complaint. Adding validation to one function but not others creates a
  split contract across the module.

## Decision

**Option A — Throw `RangeError` on inverted bounds; trust caller on types.**

Rationale:

1. **Consistency.** `add` and `subtract` perform no type validation; `clamp`
   should not introduce a different contract. Callers already assume "numbers
   in, numbers out."
2. **Fail-fast on logic errors.** Inverted bounds (`lo > hi`) almost always
   indicates a caller mistake, not a valid use case. Throwing makes the bug
   visible immediately rather than hiding it behind a silent swap.
3. **Minimal surface change.** Only one new function and one new error path are
   added. No changes to existing functions, no new dependencies, no new files
   beyond the standard workflow artifacts.

## Consequences

- `clamp` will be the first function in the module that can throw. Callers that
  currently assume every calculator function is total must account for this, but
  only when they pass inverted bounds — a scenario that is itself a bug.
- The designer should specify the exact `RangeError` message and confirm that
  `clamp(x, n, n)` (equal bounds) returns `n` without throwing.
- Future functions that accept range-like arguments should follow the same
  "throw on inverted bounds, trust types" convention.

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Callers surprised by the first thrown error in the module | Low | Document the throw in the design spec; cover it with a dedicated test |
| `lo > hi` swap is actually desired by some callers | Very low | Callers can swap before calling; a convenience wrapper is out of scope |
| Type-trusting posture lets NaN/undefined slip through silently | Low | Accepted project-wide; revisit only if a type-validation policy is adopted for all functions |

## References

- Planning artifact: `docs/plans/clamp.md`
- Project conventions: `CLAUDE.md` (Calculator Project Agent Rules)
