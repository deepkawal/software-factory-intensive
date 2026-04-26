# Calculator Memory Work Package

## Goal

Add memory functionality to the calculator so users can store a numeric value,
recall it later, and clear the stored value. This mirrors the M+/MR/MC buttons
on a physical calculator.

## User Stories

1. **Store a value** — As a user, I can store a number in memory so I can reuse
   it in a later calculation.
2. **Recall a value** — As a user, I can recall the stored number so I can use
   it as an operand without retyping it.
3. **Clear memory** — As a user, I can clear the stored number so memory is
   empty for a fresh calculation.
4. **Default state** — As a user, when no value has been stored (or after
   clearing), recalling memory returns 0, matching standard calculator behavior.

## Acceptance Criteria

- `memoryStore(value)` saves the given number.
- `memoryRecall()` returns the last stored number.
- `memoryClear()` resets memory so the next recall returns 0.
- Calling `memoryRecall()` before any store returns 0.
- Calling `memoryClear()` then `memoryRecall()` returns 0.
- Storing a new value overwrites the previous one (single-slot memory).
- All three functions are exported from `src/calculator.js` alongside existing
  `add` and `subtract`.
- A matching `test/calculator.test.js` file covers at least: store-then-recall,
  recall-without-store, clear-then-recall, and overwrite-previous-store.

## Scope Boundary

**In scope:**
- Single-slot memory (one stored value at a time).
- Pure module-level state within `src/calculator.js`.
- Tests using `node:test`.

**Out of scope:**
- Multi-slot or named memory registers.
- Memory add/subtract (M+/M−) operations.
- Persistent storage across process restarts.
- UI or CLI integration.

## Dependencies

- None beyond what already exists. The project has zero dependencies and uses
  Node's built-in test runner.

## Open Questions

1. **Memory isolation across tests** — Module-level state persists across tests
   in the same process. The architect should decide whether to accept this
   (tests call `memoryClear()` in setup) or introduce a reset mechanism.
2. **Input validation** — Should `memoryStore` reject non-number arguments, or
   is that out of scope for this minimal project?

## Architect Handoff

The architect should resolve:

- **State management approach**: module-scoped variable vs. a factory/closure
  that allows independent instances. Module-scope is simpler but harder to test
  in isolation.
- **API surface**: whether to export three separate functions
  (`memoryStore`, `memoryRecall`, `memoryClear`) or a single `memory` object
  with methods.
- **Test isolation strategy**: how tests reset state between cases given
  module-level memory.
