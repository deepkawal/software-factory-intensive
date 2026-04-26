# Undo/Redo History Work Package

## Goal

Add an undo/redo history feature to the calculator so users can step backward
and forward through a sequence of computed results. This gives the calculator
a linear operation history, similar to Ctrl-Z / Ctrl-Shift-Z in desktop
applications.

## User Stories

1. As a user, I can undo the last operation so that I return to the previous
   result, correcting a mistake without starting over.
2. As a user, I can redo a previously undone operation so that I can step
   forward again if I undo too far.
3. As a user, I can push a new result onto the history so that every
   calculation is recorded for later undo.
4. As a user, performing a new operation after an undo discards the
   redo-forward history, so the timeline stays linear and predictable.
5. As a user, I can query the current value from the history so that I
   always know what the "active" result is.
6. As a user, I can clear the entire history so that the calculator resets
   to a clean state.

## Acceptance Criteria

All tests must use `node:test` with `describe`/`it` blocks and
`node:assert/strict` for assertions (e.g., `assert.strictEqual`,
`assert.deepStrictEqual`). Use `beforeEach` inside `describe` blocks to
reset history state before each test case, ensuring test isolation.

- `push(value)` appends a result to the history and sets it as the current
  value.
- `undo()` moves the current position one step back and returns the previous
  value. Returns `undefined` (or a sentinel) when there is nothing to undo.
- `redo()` moves the current position one step forward and returns the
  restored value. Returns `undefined` (or a sentinel) when there is nothing
  to redo.
- `current()` returns the value at the current history position, or
  `undefined` when history is empty.
- `clear()` resets the history to its initial empty state.
- Calling `push()` after one or more `undo()` calls discards all entries
  ahead of the current position (redo-forward history is lost).
- Multiple consecutive `undo()` calls walk back through the full history
  in order.
- Multiple consecutive `redo()` calls walk forward through the full
  previously-undone history in order.
- `undo()` on an empty history returns `undefined` without error.
- `redo()` when there is nothing to redo returns `undefined` without error.
- All five functions are exported from a new `src/history.js` module.
- A matching `test/history.test.js` covers every criterion above, organized
  as `describe('history', () => { ... })` with individual `it(...)` cases
  and a `beforeEach` that calls `clear()`.

## Scope Boundary

**In scope:**
- `push`, `undo`, `redo`, `current`, `clear` functions.
- Pure in-process state (array + index); no persistence across runs.
- One test file with at least one `it(...)` case per acceptance criterion,
  grouped under `describe`.

**Out of scope:**
- Branching / tree-style history (only linear undo/redo).
- Storing operation metadata (operator, operands) — only result values.
- Configurable history depth / max length.
- Persistent storage (file, database).
- Integration with a REPL, CLI, or UI layer.
- Integration with the memory module (`src/memory.js`) or calculator
  module (`src/calculator.js`).

## Dependencies

- None beyond what the project already uses (Node.js, `node:test`).
- The new module is independent of `src/calculator.js` and `src/memory.js`;
  no changes to existing files are required.

## Open Questions

1. Should `push` accept only finite numbers, or also allow arbitrary values
   (strings, objects) to support future expression-history use cases?
   Recommend: accept any JS value for flexibility; document that the
   typical use case is numbers.
2. Should there be a `size()` or `canUndo()` / `canRedo()` helper?
   Recommend: defer; callers can check the return value of `undo()`/`redo()`
   for `undefined`.
3. Should history have a maximum depth to bound memory usage?
   Recommend: defer; unbounded for now, note as a future enhancement.

## Architect Handoff

The architect should resolve:

1. **State strategy** — module-level array + index (singleton) vs. a factory
   function (`createHistory()`) that returns an independent history instance.
   A factory makes test isolation trivial (`beforeEach` creates a fresh
   instance) and supports multiple calculator sessions later; a singleton
   is simpler but couples all callers to shared state.
2. **Undo-past-beginning behavior** — return `undefined`, return a sentinel
   like `null`, or throw. This affects the public API contract and how
   callers detect "nothing to undo."
3. **Module boundary** — confirm that history lives in its own
   `src/history.js` rather than being added to `src/calculator.js`. A
   separate module follows the existing pattern (`src/memory.js`) and keeps
   concerns distinct.
4. **Push-after-undo truncation** — confirm that discarding forward history
   is the right behavior (standard in most undo systems) vs. keeping a
   branching tree.
