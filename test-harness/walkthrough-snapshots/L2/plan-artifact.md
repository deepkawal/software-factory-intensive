# Calculator Memory Work Package

## Goal

Add memory functionality to the calculator so users can store a value, recall
it later, and clear the stored value. This mirrors the M+/MR/MC buttons on
a physical calculator and gives users a way to hold an intermediate result
across multiple operations.

## User Stories

1. **Store a value** — As a user, I can store a numeric value in memory so
   that I can reuse it in a later calculation.
2. **Recall a value** — As a user, I can recall the stored value so that I
   can use it as an operand without retyping it.
3. **Clear memory** — As a user, I can clear the stored value so that
   memory starts fresh and does not leak between unrelated calculations.
4. **Add to memory** — As a user, I can add a value to the current memory
   contents (M+ behavior) so that I can accumulate a running total.
5. **Default state** — As a user, when no value has been stored, recalling
   memory returns 0 so that calculations using recall never produce NaN or
   errors.

## Acceptance Criteria

- `memoryStore(value)` saves a numeric value.
- `memoryRecall()` returns the most recently stored value, or `0` if memory
  is empty.
- `memoryClear()` resets memory to the empty/default state.
- `memoryAdd(value)` adds the given value to the current memory contents.
- All four functions are exported from a new `src/memory.js` module.
- A matching `test/memory.test.js` exists with at least one test per
  exported function, covering:
  - Store then recall returns the stored value.
  - Recall before any store returns `0`.
  - Clear resets memory so recall returns `0`.
  - memoryAdd accumulates correctly across multiple calls.
- `node --test` passes with zero failures after the change.
- No changes to existing `src/calculator.js` exports or behavior.

## Scope Boundary

**In scope:**
- The four memory functions listed above.
- A single in-process memory slot (one value at a time).
- Pure-function style: the module holds module-level state, no classes needed.

**Out of scope:**
- Multiple named memory slots or a memory stack.
- Persistence across process restarts (memory is ephemeral).
- Integration with a REPL, CLI, or UI layer.
- Multiply/subtract variants of memory operations (M−, M×).

## Dependencies

- None beyond what the project already uses (Node built-ins only).
- The new module should follow the same CommonJS export pattern as
  `src/calculator.js`.

## Open Questions

1. Should `memoryStore` silently overwrite an existing stored value, or
   should it warn/return the old value? **Assumption:** silent overwrite,
   matching standard calculator behavior.
2. Should non-numeric arguments throw or be silently coerced?
   **Assumption:** accept only numbers; throw a `TypeError` for non-numeric
   input, keeping the library strict.

## Architect Handoff

The architect should resolve:

1. **Module-level mutable state vs. factory function** — The simplest
   design uses a module-scoped `let` for the stored value. An alternative
   is a `createMemory()` factory that returns an object with store/recall/
   clear/add methods, making tests fully isolated. The architect should
   decide which pattern fits the project's conventions.
2. **Input validation strategy** — Whether to throw on bad input, silently
   coerce with `Number()`, or leave validation to callers. This affects the
   test surface and the error contract downstream stages rely on.
3. **Integration surface** — Whether `calculator.js` should re-export
   memory functions for a single-import experience, or whether consumers
   import `memory.js` separately. This affects the public API shape.
