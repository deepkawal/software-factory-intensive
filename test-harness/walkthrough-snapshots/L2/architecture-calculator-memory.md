# Calculator Memory Architecture

## Context

The calculator project needs a memory feature (store, recall, clear) as
described in `docs/plans/calculator-memory.md`. The existing codebase is a
minimal CommonJS project with pure functions exported from `src/calculator.js`.
No classes, no shared state, no build tooling.

The planner identified three decisions the architect must resolve: state
strategy, input validation, and module boundary.

## Options Considered

### 1. State Strategy

**Option A — Module-level variable (singleton)**

A `let` variable inside `src/memory.js` holds the stored value. The three
exported functions read and write that variable directly.

| Pro | Con |
|-----|-----|
| Simplest possible implementation | Singleton — tests share state unless each test calls `memoryClear()` |
| Matches the style of `src/calculator.js` (stateless module, plain functions) | Cannot support multiple independent memory slots later without refactoring |
| Zero ceremony for callers | |

**Option B — Factory function returning a memory object**

Export a `createMemory()` factory that returns `{ store, recall, clear }`,
each closing over its own private variable.

| Pro | Con |
|-----|-----|
| Tests get isolated instances for free | More ceremony: callers must call `createMemory()` first |
| Supports multiple memory contexts without refactoring | Breaks the project's convention of exporting plain functions |
| Encapsulation is explicit | Overkill for current scope (single-slot, no persistence) |

### 2. Input Validation

**Option A — Accept any JS number (including Infinity and NaN)**

`memoryStore` accepts whatever `typeof value === 'number'` passes.

| Pro | Con |
|-----|-----|
| Simple, predictable, no surprises | Storing `NaN` then recalling it may confuse downstream code |
| Matches how JS arithmetic already behaves (add returns NaN/Infinity freely) | |

**Option B — Throw on non-finite or non-number input**

`memoryStore` throws a `TypeError` for non-numbers and a `RangeError` for
`Infinity`/`NaN`.

| Pro | Con |
|-----|-----|
| Catches bugs early | Adds validation code and tests for error paths |
| Clear contract | `src/calculator.js` does not validate inputs — inconsistent |

### 3. Module Boundary

**Option A — Separate `src/memory.js` module**

| Pro | Con |
|-----|-----|
| Single-responsibility; memory is independent of arithmetic | One more file in a small project |
| No risk of breaking existing `calculator.js` exports or tests | |

**Option B — Add memory functions to `src/calculator.js`**

| Pro | Con |
|-----|-----|
| Fewer files | Mixes stateful memory with stateless arithmetic |
| | Existing tests must not break; risk of accidental coupling |
| | Violates separation of concerns |

## Decision

1. **State strategy: Option A — module-level variable.** The project
   convention is small pure functions with no classes. A singleton `let`
   variable is the simplest approach that satisfies every acceptance criterion.
   Tests can call `memoryClear()` in setup to isolate state. If the project
   later needs multiple memory contexts, the refactor to a factory is
   mechanical and low-risk.

2. **Input validation: Option A — accept any JS number.** The existing
   `calculator.js` performs no input validation; adding strict checks only in
   the memory module would be inconsistent. `Infinity` and `NaN` are valid JS
   numbers and can be stored without special handling. The planner's open
   question recommended this approach for simplicity.

3. **Module boundary: Option A — separate `src/memory.js`.** Memory introduces
   mutable state, which is a different concern from the pure arithmetic
   functions in `calculator.js`. A separate module avoids coupling and keeps
   both files easy to reason about.

## Consequences

- A new `src/memory.js` exports `memoryStore`, `memoryRecall`, `memoryClear`.
- A new `test/memory.test.js` covers every acceptance criterion (at least 5
  tests).
- No changes to `src/calculator.js` or `test/calculator.test.js`.
- Module-level state means a single memory slot per process; tests must call
  `memoryClear()` before or after each test to avoid leaking state.
- The public API accepts any JS number; callers are responsible for checking
  `NaN`/`Infinity` if that matters to their use case.

## Risks

- **Shared test state:** If a test forgets to clear memory, later tests may
  see stale values. Mitigation: document the pattern and include
  `memoryClear()` in a `beforeEach` in the test file.
- **Singleton limits:** If the project later needs multiple memory slots or
  server-side isolation per request, the singleton must be refactored.
  Mitigation: the refactor is small (wrap in a factory, re-export convenience
  singleton) and the plan explicitly defers multi-slot to a future request.

## References

- Planning artifact: `docs/plans/calculator-memory.md`
- Project conventions: `CLAUDE.md`
- Existing implementation: `src/calculator.js`
