# Undo/Redo History Work Package

## Goal

Add an undo/redo history system to the calculator so users can step backward
and forward through past calculation results. Each call to `add` or `subtract`
(and any future operations) pushes a record onto the history stack. Undoing
restores the previous result; redoing re-applies the last undone result. A new
operation after an undo discards the redo branch.

## User Stories

1. **Undo last operation** — As a user, I can undo the most recent calculation
   so I can return to the previous result without re-entering it.
2. **Redo an undone operation** — As a user, I can redo a previously undone
   calculation so I can step forward again without repeating the operation.
3. **Chain undo/redo** — As a user, I can undo or redo multiple times in
   sequence to navigate through my calculation history.
4. **New operation clears redo** — As a user, when I perform a new calculation
   after undoing, the redo stack is discarded so the history stays linear.
5. **Inspect history** — As a user, I can retrieve the full history list so I
   can see what operations were performed.
6. **Clear history** — As a user, I can reset the history so I start fresh.

## Acceptance Criteria

- `record(entry)` pushes an operation record `{ op, args, result }` onto the
  history stack and resets the redo branch.
- `undo()` moves the cursor back one step and returns the previous entry, or
  `null` when at the beginning.
- `redo()` moves the cursor forward one step and returns the re-applied entry,
  or `null` when at the end.
- `getHistory()` returns the full array of recorded entries (not a copy
  requirement — architect decides).
- `clearHistory()` empties the stack and resets the cursor.
- Performing `undo()` then `record(entry)` discards all entries after the
  cursor (no orphan redo branch).
- Multiple consecutive `undo()` calls walk backward one step each.
- Multiple consecutive `redo()` calls walk forward one step each.
- `undo()` on an empty history returns `null`.
- `redo()` with nothing undone returns `null`.
- All functions are exported from a new `src/history.js` module via
  `module.exports = { record, undo, redo, getHistory, clearHistory }`.
- A matching `test/history.test.js` uses `node:test` with `describe`/`it`
  blocks and `node:assert/strict` (`assert.strictEqual`, `assert.deepStrictEqual`)
  covering at minimum:
  - record-then-undo returns the previous entry
  - redo after undo returns the re-applied entry
  - undo on empty history returns `null`
  - redo with nothing undone returns `null`
  - new record after undo discards the redo branch
  - clearHistory resets to empty
  - chained undo/redo navigation across 3+ entries

## Scope Boundary

**In scope:**
- A standalone `src/history.js` module with module-level state.
- Linear undo/redo stack (single branch, no tree).
- Plain object entries `{ op, args, result }`.
- Tests using `node:test` (`describe`, `it`) and `node:assert/strict`.

**Out of scope:**
- Automatic wrapping of `add`/`subtract` to record on every call (the caller
  is responsible for calling `record`).
- Persistent or serializable history across process restarts.
- Branching / tree-structured undo.
- Size limits or eviction policy on the history stack.
- UI or CLI integration.

## Dependencies

- None. The module is self-contained with zero external dependencies.
- The existing `src/calculator.js` is not modified; history is a parallel
  module.

## Open Questions

1. **State isolation in tests** — Module-level state persists across `it`
   blocks in the same file. The architect should decide whether tests call
   `clearHistory()` in a `beforeEach` hook or whether the module exposes a
   factory/closure for independent instances.
2. **Return value semantics** — Should `undo`/`redo` return the full entry
   object or only the `result` field? Returning the object is more informative;
   returning just the result is simpler.
3. **Integration with calculator** — Should `src/calculator.js` import history
   and record automatically, or should that wiring live in a future integration
   layer? The plan assumes the caller wires it, but the architect may prefer
   built-in recording.

## Architect Handoff

The architect should resolve:

- **Module-level state vs. factory** — A single module-scoped array is
  simplest but makes test isolation harder. A `createHistory()` factory
  returning an instance with its own stack is more testable. Choose one.
- **Return type of undo/redo** — Full entry object `{ op, args, result }` vs.
  just `result`. Affects downstream consumers.
- **getHistory mutability** — Return the internal array directly (fast, caller
  can mutate) or a shallow copy (safe, slight overhead).
- **Integration strategy** — Whether `calculator.js` should auto-record via
  history, or remain pure with history wired externally.
