# Pizza Ratings and Reviews Validation

**Work package:** [`docs/plans/pizza-ratings-and-reviews.md`](../plans/pizza-ratings-and-reviews.md)
**ADR:** [`docs/architecture/pizza-ratings-and-reviews.md`](../architecture/pizza-ratings-and-reviews.md)
**Design:** [`docs/designs/pizza-ratings-and-reviews.md`](../designs/pizza-ratings-and-reviews.md)
**Implementation commit:** `f27f433` — `feat: add per-pizza ratings and reviews`
**Root bead:** `fup-xj3`
**Builder step:** `fup-1zo`
**Validator step:** `fup-eqi`
**Generated:** 2026-05-01

---

## Verdict

PASS

## Test Command

```bash
npm test
```

(Resolves to `vitest run` per `package.json`.)

A supplementary type-check was also run, since the plan's acceptance
criterion 3 requires `tsc --noEmit` clean under strict mode:

```bash
npx tsc --noEmit
```

## Results

### `npm test` — 79 passed / 79 total

```
 RUN  v2.1.9 /Users/austin/actual/software-factory-intensive/reference-project/fired-up-pizza

 ✓ src/client/lib/format.test.ts (16 tests) 8ms
 ✓ src/server/lib/reviews-validation.test.ts (11 tests) 16ms
 ✓ src/server/db/reviews.test.ts (13 tests) 13ms
 ✓ src/client/pages/PizzaDetailPage.test.tsx (4 tests) 132ms
 ✓ src/client/components/RatingBadge.test.tsx (4 tests) 171ms
 ✓ src/client/components/ReviewList.test.tsx (4 tests) 210ms
 ✓ src/client/components/RatingInput.test.tsx (6 tests) 366ms
 ✓ src/server/routes/menu-item-reviews.test.ts (12 tests) 228ms
 ✓ src/client/components/ReviewSubmissionForm.test.tsx (9 tests) 412ms

 Test Files  9 passed (9)
      Tests  79 passed (79)
   Start at  09:16:42
   Duration  1.97s
```

Per-file breakdown matches the Test Plan in the design spec:

| File | Tests | Maps to design section |
|------|------:|------------------------|
| `src/server/db/reviews.test.ts` | 13 | `submitReview`, `listRecentReviewsForPizza`, `listMenuItemsWithAggregates`, `getMenuItemWithAggregate` (storage layer) |
| `src/server/lib/reviews-validation.test.ts` | 11 | `parseSubmission` rules (rating/text/phone bounds) |
| `src/server/routes/menu-item-reviews.test.ts` | 12 | All four HTTP endpoints, status codes, PII boundary on the wire |
| `src/client/lib/format.test.ts` | 16 | `formatRating`, `formatReviewCount`, `formatRelativeTime`, `maskPhoneTail` |
| `src/client/components/RatingBadge.test.tsx` | 4 | Empty vs populated badge states |
| `src/client/components/RatingInput.test.tsx` | 6 | Click + keyboard interactions, disabled state |
| `src/client/components/ReviewList.test.tsx` | 4 | Empty state copy, populated rows, ISO `<time>` element |
| `src/client/components/ReviewSubmissionForm.test.tsx` | 9 | `idle → editing → submitting → saved/error` state machine, PII non-leak |
| `src/client/pages/PizzaDetailPage.test.tsx` | 4 | Skeleton/happy path/404/invalid id |

### `npx tsc --noEmit` — clean

The command exited with status 0 and no diagnostic output. Strict-mode
type-checking passes across the project.

### Acceptance criteria spot-check (against test names + tests)

The plan's Acceptance Criteria require all Story 1/2/3 acceptance criteria
to pass. The test suite covers each one explicitly:

- **Story 1 AC1 (eligibility tied to non-cancelled order):** covered by
  `src/server/db/reviews.test.ts` `submitReview returns ineligible when …`
  cases and the `ineligible` branch in
  `src/server/routes/menu-item-reviews.test.ts`.
- **Story 1 AC2 (rating ∈ [1,5]):** covered by
  `src/server/lib/reviews-validation.test.ts` (`rating 0`, `rating 6`,
  `rating 4.5`, `rating "4"`).
- **Story 1 AC3 (review_text ≤ 200 chars after trim):** covered by the
  validation test file (`length 200 accepted`, `length 201 rejected`,
  whitespace-only → `null`, `wrong_type`).
- **Story 1 AC4 (one review per (pizza, phone), upsert in place):**
  covered by `submitReview updates an existing row in place …` and the
  POST 200-on-resubmit case in the route test.
- **Story 1 AC6 (201 / 200 with stored payload incl. `phone_number`):**
  covered by `POST returns 201 + the inserted row …` and `POST returns
  200 + the updated row …` in the route test, plus the
  `OwnReview`-shape assertion (`response includes phone_number on the
  201 / 200 paths only`).
- **Story 2 AC1 (numeric to 1 decimal + count):** covered by
  `formatRating(4.3) === "4.3"`, `formatRating(5) === "5.0"`,
  `formatReviewCount` cases.
- **Story 2 AC2 (empty state ≠ "0.0 (0)"):** covered by the
  `RatingBadge` empty-state tests and the `avg_rating: null` aggregate
  test in `reviews.test.ts`.
- **Story 2 AC3 (single-query menu list, no fan-out):** covered by
  `listMenuItemsWithAggregates` test cases that read every pizza in one
  call.
- **Story 2 AC4 (no drift between aggregate and ledger):** structural —
  the SQL is a `LEFT JOIN` over the live `reviews` table; no cached
  counter exists. Verified by code inspection of
  `src/server/db/reviews.ts`.
- **Story 2 AC5 (unavailable pizzas keep their aggregate):** covered by
  `listMenuItemsWithAggregates includes pizzas with available = false`.
- **Story 3 AC1 (`/menu/:pizzaId` route + aggregate + base fields):**
  covered by `PizzaDetailPage renders header + badge + populated reviews
  on the happy path` and the route-table addition in `src/main.tsx`.
- **Story 3 AC2 (10 most recent, ordered by updated_at DESC):** covered
  by `listRecentReviewsForPizza` test cases (ordering, limit honored).
- **Story 3 AC3 (masked phone tail only):** covered by the
  `phone_tail`-projection test in `reviews.test.ts` and the
  `maskPhoneTail` test in `format.test.ts`; route-level PII boundary
  asserted in `menu-item-reviews.test.ts`.
- **Story 3 AC4 (empty state + hint):** covered by `ReviewList renders
  the empty state when reviews.length === 0` and its hint assertion.
- **Story 3 AC5 (unknown pizzaId → not-found, not server error):**
  covered by `PizzaDetailPage renders the not-found state on a 404 …`
  and the route test for `GET /api/v1/menu-items/:id` 404.

The plan's overall acceptance criterion 3 also requires `tsc --noEmit`
clean and Vitest green, both confirmed above. Acceptance criterion 5
(register the `Review` entity in the Project Manifest's Domain Model)
was satisfied by the implementation commit, which adds the `Review`
line to `docs/PROJECT_MANIFEST.md`.

## Issues

No required check failed.

The following observations are noted for the Reviewer / Release-Gate
steps but did not fail validation:

- **ESLint is not configured.** `npm run lint` exits non-zero with
  "ESLint couldn't find an eslint.config.(js|mjs|cjs) file." This is a
  pre-existing project-infrastructure gap (ESLint v9 dropped the legacy
  `.eslintrc.*` format) — not a regression introduced by the
  implementation commit. The plan's acceptance criterion lists "ESLint
  clean" alongside Vitest and `tsc --noEmit`; the work package did not
  include an ESLint-config migration in its scope. Flagging here so the
  Reviewer can decide whether to file a follow-up bead for an ESLint v9
  flat-config migration. Validation does not block on this because the
  test command and type-check (the validator's required checks) both
  pass and the gap is orthogonal to the feature under test.
- **React Router v7 future-flag warnings** appear in the
  `PizzaDetailPage.test.tsx` stderr (`v7_startTransition`,
  `v7_relativeSplatPath`). Informational only; tests still pass and the
  warnings are emitted by the library, not the implementation.

## References

- Plan: [`docs/plans/pizza-ratings-and-reviews.md`](../plans/pizza-ratings-and-reviews.md)
- ADR: [`docs/architecture/pizza-ratings-and-reviews.md`](../architecture/pizza-ratings-and-reviews.md)
- Design: [`docs/designs/pizza-ratings-and-reviews.md`](../designs/pizza-ratings-and-reviews.md)
- Project manifest: [`docs/PROJECT_MANIFEST.md`](../PROJECT_MANIFEST.md)
- Factory wiring: [`docs/factory-wiring.md`](../factory-wiring.md)
- Implementation commit: `f27f433`
- Source request: bead `fup-upt`
- Workflow bead: `fup-xj3`
- Builder step: `fup-1zo`
- Validator step: `fup-eqi`
