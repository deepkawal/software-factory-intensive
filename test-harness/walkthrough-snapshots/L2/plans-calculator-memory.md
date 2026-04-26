# Calculator Memory Work Package

## Goal

Add a memory feature to the calculator so users can store a numeric value,
recall it later, and clear the stored value. This mirrors the M+/MR/MC
buttons on a physical calculator.

## User Stories

1. As a user, I can store a number in memory so I can reuse it in a later
   calculation.
2. As a user, I can recall the stored number so I can use it as an operand
   without re-entering it.
3. As a user, I can clear memory so it resets to its initial state (zero).
4. As a user, recalling memory when nothing has been stored returns zero, so
   behavior is predictable without requiring an explicit initialization step.

## Acceptance Criteria

- `memoryStore(value)` saves the given number.
- `memoryRecall()` returns the most recently stored number.
- `memoryClear()` resets the stored value to `0`.
- Calling `memoryRecall()` before any store returns `0`.
- Calling `memoryClear()` then `memoryRecall()` returns `0`.
- Storing a new value overwrites the previous one (single-slot memory).
- All three functions are exported from a new `src/memory.js` module.
- A matching `test/memory.test.js` covers every acceptance criterion above.

## Scope Boundary

**In scope:**
- `memoryStore`, `memoryRecall`, `memoryClear` functions.
- Pure in-process state (module-level variable); no persistence across runs.
- One test file with at least one test per acceptance criterion.

**Out of scope:**
- Multiple memory slots or named registers.
- Persistent storage (file, database).
- Integration with a REPL, CLI, or UI layer.
- Cumulative memory operations (M+, M−) — only direct store/overwrite.

## Dependencies

- None beyond what the project already uses (Node.js, `node:test`).
- The new module is independent of `src/calculator.js`; no changes to existing
  files are required.

## Open Questions

1. Should `memoryStore` accept only finite numbers, or also allow `Infinity`
   and `NaN`? Recommend: accept any JS number for simplicity; document behavior.
2. Should the memory module expose a way to check whether memory has been
   explicitly set (e.g., `memoryHasValue()`)? Recommend: defer to a future
   request; keep the API minimal for now.

## Architect Handoff

The architect should resolve:

1. **State strategy** — module-level `let` variable vs. a factory function that
   returns a memory object. Module-level state is simpler but creates a
   singleton; a factory supports independent instances (useful if tests need
   isolation or if the project later supports multiple calculator sessions).
2. **Input validation** — whether `memoryStore` should throw on non-number
   input or silently coerce/ignore. This affects the public API contract.
3. **Module boundary** — confirm that memory lives in its own `src/memory.js`
   rather than being added to `src/calculator.js`. A separate module keeps
   concerns distinct but adds a file; folding it in keeps the project small.
