# Calculator Memory Architecture

## Context

The calculator currently exports two pure, stateless functions (`add`, `subtract`)
from `src/calculator.js`. The planner's work package asks for single-slot memory
(store, recall, clear) — the first stateful behavior in the module. Three
architectural questions need resolution before implementation: state management
approach, API surface shape, and test isolation strategy.

## Options Considered

### State Management

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A. Module-scoped variable** | A single `let _memory = 0` at module level, mutated by the three functions. | Minimal change; matches the existing flat-function style; no new patterns to learn. | State is a module-level singleton — two callers in the same process share one slot. Tests must explicitly reset. |
| **B. Factory / closure** | Export a `createMemory()` that returns `{ store, recall, clear }` bound to a private variable. | Each call gets independent state; trivially testable in isolation. | Introduces a new pattern (factory) not present in the codebase; callers must manage the instance; conflicts with the project rule "prefer small pure functions over classes". |

### API Surface

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A. Three flat functions** | Export `memoryStore`, `memoryRecall`, `memoryClear` alongside `add` and `subtract`. | Consistent with existing export style; destructured import works identically to current tests. | Five top-level exports — acceptable for this module size but would not scale if many more features are added. |
| **B. Namespaced object** | Export a `memory` object with `.store()`, `.recall()`, `.clear()` methods. | Groups related operations; keeps the top-level export list short. | Breaks the established pattern; requires `const { memory } = require(...)` followed by `memory.store(...)`, adding a level of indirection. |

### Test Isolation

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A. `memoryClear()` in setup** | Each test (or a `beforeEach`) calls `memoryClear()` to reset shared state. | Uses the public API; no magic; easy to read. | Tests are order-dependent if a developer forgets the reset call. |
| **B. Fresh `require` per test** | Delete `require.cache` entry and re-import the module in each test to get a fresh variable. | Guaranteed isolation without any public reset API. | Brittle; couples tests to Node's module caching internals; unconventional. |

## Decision

**Module-scoped variable + three flat functions + `memoryClear()` reset in tests.**

Rationale:

1. **Module-scoped variable (Option A)** — The project is a minimal, single-user
   calculator. Singleton state is appropriate and keeps the implementation to a
   one-line variable declaration. The factory pattern adds complexity without a
   real-world benefit for this scope.

2. **Three flat functions (Option A)** — `memoryStore`, `memoryRecall`, and
   `memoryClear` export alongside `add` and `subtract` using the same
   `module.exports = { ... }` pattern. No new abstractions. The acceptance
   criteria already name these functions, so this avoids any naming mismatch.

3. **`memoryClear()` reset (Option A)** — Each test calls `memoryClear()` at the
   top (or in a `beforeEach` block). This is explicit, uses the public API, and
   keeps tests self-documenting. The risk of forgetting a reset is low given the
   small test surface.

On the planner's open questions:

- **Input validation** — Out of scope. The existing `add` and `subtract` do no
  validation. Memory functions should follow the same convention.
- **Memory isolation across tests** — Resolved by the `memoryClear()` reset
  strategy above.

## Consequences

- `src/calculator.js` gains one module-level `let` and three exported functions.
  The export object grows from two to five entries.
- `test/calculator.test.js` gains memory-specific tests, each starting with a
  `memoryClear()` call. Existing `add`/`subtract` tests are unaffected.
- No new files, dependencies, or patterns are introduced.
- Future expansion (M+/M−, multi-slot) would require revisiting the module-scope
  decision, but that is explicitly out of scope per the plan.

## Risks

1. **Shared mutable state** — If the calculator module is ever imported by
   concurrent callers (e.g., a future HTTP handler), the singleton memory slot
   would be shared. Mitigation: the project scope is a single-user CLI/test
   exercise; this risk is accepted.
2. **Test ordering sensitivity** — A missing `memoryClear()` call could cause
   a test to pass or fail depending on execution order. Mitigation: use
   `beforeEach` in the test file to make the reset automatic and visible.

## References

- Planning artifact: `docs/plans/calculator-memory.md`
- Existing source: `src/calculator.js`
- Project conventions: `CLAUDE.md` (root of rig)
