# Calculator Memory Architecture

## Context

The calculator project needs memory operations (store, recall, clear, add-to-memory) that mirror M+/MR/MC on a physical calculator. The existing codebase is a single `src/calculator.js` module exporting pure arithmetic functions via CommonJS. There are no classes, no build tools, and zero dependencies. The planner artifact identifies three architectural questions the architect must resolve: state management pattern, input validation strategy, and integration surface.

## Options Considered

### 1. State Management

**Option A: Module-scoped `let` variable**

A single `let memory = 0` at module scope. The four exported functions read and write this variable directly.

| Dimension | Assessment |
|-----------|------------|
| Simplicity | Matches the existing `calculator.js` pattern — flat functions, no constructors |
| Testability | Tests share mutable state; ordering or parallel execution can cause interference |
| Reset cost | `memoryClear()` is the only reset path; forgetting to call it leaks state between tests |

**Option B: Factory function (`createMemory()`)**

A `createMemory()` factory returns an object with `store`, `recall`, `clear`, and `add` methods, each closing over a private `let`.

| Dimension | Assessment |
|-----------|------------|
| Isolation | Each call produces an independent instance; tests never share state |
| Convention fit | Introduces a constructor-like pattern that nothing else in the project uses |
| Consumer complexity | Callers must instantiate before using; adds one extra step vs. direct imports |

### 2. Input Validation

**Option A: Strict — throw `TypeError` on non-numeric input**

Each mutating function checks `typeof value !== 'number' || Number.isNaN(value)` and throws immediately.

| Dimension | Assessment |
|-----------|------------|
| Safety | Catches misuse early; callers get a clear error message |
| Consistency | `calculator.js` does no validation today, so this is stricter than the existing convention |
| Test surface | Requires explicit error-path tests |

**Option B: No validation — caller's responsibility**

Functions accept whatever is passed, same as `add(a, b)` and `subtract(a, b)` today.

| Dimension | Assessment |
|-----------|------------|
| Consistency | Matches the existing `calculator.js` contract exactly |
| Risk | Silent garbage-in/garbage-out; `memory + undefined` produces `NaN` without warning |

### 3. Integration Surface

**Option A: Separate import (`require('./memory')`)**

Consumers import `memory.js` independently. `calculator.js` is untouched.

| Dimension | Assessment |
|-----------|------------|
| Isolation | Zero risk of breaking existing calculator exports or tests |
| Scope compliance | Plan explicitly requires "no changes to existing `src/calculator.js` exports or behavior" |

**Option B: Re-export from `calculator.js`**

`calculator.js` re-exports memory functions for a unified import.

| Dimension | Assessment |
|-----------|------------|
| Convenience | Single import for all calculator operations |
| Violation | Directly contradicts the plan's scope constraint |

## Decision

1. **Module-scoped `let` (Option A).** The project convention is flat pure-ish functions with CommonJS exports. Introducing a factory pattern for one module creates an inconsistency. Test isolation is addressed by calling `memoryClear()` in a `beforeEach` hook, which is trivial.

2. **Strict validation — throw `TypeError` (Option A).** Although `calculator.js` does not validate today, memory operations mutate state. A silent `NaN` stored in memory would propagate errors invisibly across later recalls. The cost of a `typeof` check is negligible and the benefit is immediate debuggability. This establishes a validation precedent the project can adopt more broadly later.

3. **Separate import (Option A).** The plan explicitly forbids changes to `calculator.js`. A separate `src/memory.js` module keeps the blast radius at zero. Future integration (a barrel `index.js`, or a CLI layer) can compose both modules without either knowing about the other.

## Consequences

- A new `src/memory.js` file is added with four exports: `memoryStore`, `memoryRecall`, `memoryClear`, `memoryAdd`.
- A new `test/memory.test.js` file covers at least one test per export plus the default-state and validation-error paths.
- `calculator.js` and its tests remain completely unchanged.
- Module-scoped state means the module is a singleton per process. If the project later needs multiple independent memory slots, a migration to the factory pattern will be required.
- The `TypeError` contract for non-numeric input becomes part of the public API; removing it later would be a breaking change.

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Test pollution from shared module state | Medium | `memoryClear()` in `beforeEach`; `node:test` runs files in separate processes by default |
| Inconsistent validation across modules (`memory` strict, `calculator` lenient) | Low | Document the difference; optionally backfill validation in `calculator.js` in a separate change |
| Future need for multiple memory slots | Low | The flat-function API can be replaced with a factory without changing call-site signatures if wrappers are added |

## References

- Planning artifact: `docs/plans/calculator-memory.md`
- Project conventions: `CLAUDE.md`
- Existing implementation: `src/calculator.js`
