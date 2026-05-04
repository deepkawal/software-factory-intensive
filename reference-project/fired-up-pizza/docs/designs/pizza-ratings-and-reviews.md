# Pizza Ratings and Reviews Design

**Work package:** [`docs/plans/pizza-ratings-and-reviews.md`](../plans/pizza-ratings-and-reviews.md)
**ADR:** [`docs/architecture/pizza-ratings-and-reviews.md`](../architecture/pizza-ratings-and-reviews.md)
**Root bead:** `fup-upt`
**Workflow bead:** `fup-xj3` (mol-release-delivery)
**Designer step:** `fup-1w0`
**Generated:** 2026-05-01

---

## Purpose

Translate the plan + ADR into an implementation-ready specification the Builder
follows unchanged unless the Reviewer approves a deviation. Every interface,
state, layout, and edge case below is normative.

The ADR fixed: storage shape (surrogate `id` + `UNIQUE(pizza_id, phone_number)`,
covering index `(pizza_id, updated_at DESC)`), aggregate strategy (live
`AVG`/`COUNT` join, NULL preserved on the wire), eligibility enforcement
(atomic conditional UPSERT), and endpoint shape (nested under
`/api/v1/menu-items/:pizzaId/reviews`). This design fills in the developer-
facing module APIs, the customer-facing UI, and the test coverage that proves
both.

---

## Interface

### Shared types — `src/shared/types/review.ts`

```ts
export interface Review {
  id: number;
  pizza_id: number;
  phone_tail: string;          // last 4 chars of the storer's phone, e.g. "4421"
  rating: number;              // integer in [1, 5]
  review_text: string | null;  // null when the customer omitted text
  created_at: number;          // unix seconds
  updated_at: number;          // unix seconds
}

// Returned only on the submission response — the customer's own row,
// echoed back to confirm the upsert. Never appears on list responses.
export interface OwnReview extends Review {
  phone_number: string;
}

export interface MenuItemWithAggregate {
  id: number;
  name: string;
  description: string;
  base_price: number;          // cents
  category: string;
  available: boolean;
  avg_rating: number | null;   // null when review_count === 0
  review_count: number;
}

export interface SubmitReviewRequest {
  phone_number: string;        // E.164-normalized at the boundary
  rating: number;              // integer 1..5
  review_text?: string;        // optional, ≤ 200 chars after trim
}
```

`avg_rating` is `null`, never `0` or `0.0`, when there are no reviews — Story 2
AC2 explicitly requires the empty case to render as "No reviews yet" rather
than "0.0 (0)". The wire type carries the discriminator the client needs.

### Server module — `src/server/db/reviews.ts`

Mirrors the conventions used elsewhere in `src/server/db/` (see Build Notes):
prepared statements declared at module top, exported functions below them,
`better-sqlite3` synchronous API throughout.

```ts
export type SubmitOutcome =
  | { kind: 'inserted'; row: OwnReview }
  | { kind: 'updated';  row: OwnReview }
  | { kind: 'ineligible' }
  | { kind: 'unknown_pizza' };

export function submitReview(input: {
  pizzaId: number;
  phoneNumber: string;        // normalized
  rating: number;             // already validated 1..5
  reviewText: string | null;  // already trimmed, length-checked
}): SubmitOutcome;

export function listRecentReviewsForPizza(
  pizzaId: number,
  limit: number,              // capped at 50 by the route handler; default 10
): Review[];

export function listMenuItemsWithAggregates(
  category?: string,          // when omitted, returns all items
): MenuItemWithAggregate[];

export function getMenuItemWithAggregate(
  pizzaId: number,
): MenuItemWithAggregate | null;
```

#### SQL bound at module top

```sql
-- Schema (added to src/server/db/schema.ts; see Build Notes)
CREATE TABLE IF NOT EXISTS reviews (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  pizza_id     INTEGER NOT NULL REFERENCES menu_items(id),
  phone_number TEXT    NOT NULL,
  rating       INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  review_text  TEXT,
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL,
  UNIQUE (pizza_id, phone_number)
);
CREATE INDEX IF NOT EXISTS idx_reviews_pizza_recent
  ON reviews (pizza_id, updated_at DESC);

-- submitReview: atomic conditional UPSERT (ADR Decision 3, Option A)
INSERT INTO reviews (pizza_id, phone_number, rating, review_text, created_at, updated_at)
SELECT @pizza_id, @phone_number, @rating, @review_text, @now, @now
WHERE EXISTS (
  SELECT 1
  FROM order_items oi
  JOIN orders o ON o.id = oi.order_id
  WHERE o.phone_number = @phone_number
    AND o.status != 'cancelled'
    AND oi.menu_item_id = @pizza_id
)
ON CONFLICT (pizza_id, phone_number) DO UPDATE
  SET rating      = excluded.rating,
      review_text = excluded.review_text,
      updated_at  = excluded.updated_at;

-- listRecentReviewsForPizza
SELECT id, pizza_id,
       SUBSTR(phone_number, -4) AS phone_tail,
       rating, review_text, created_at, updated_at
FROM   reviews
WHERE  pizza_id = @pizza_id
ORDER  BY updated_at DESC, id DESC
LIMIT  @limit;

-- listMenuItemsWithAggregates (single query, no fan-out — Story 2 AC3)
SELECT m.id, m.name, m.description, m.base_price, m.category, m.available,
       ROUND(AVG(r.rating), 1) AS avg_rating,
       COUNT(r.id)             AS review_count
FROM   menu_items m
LEFT   JOIN reviews r ON r.pizza_id = m.id
WHERE  (@category IS NULL OR m.category = @category)
GROUP  BY m.id;

-- getMenuItemWithAggregate
SELECT m.id, m.name, m.description, m.base_price, m.category, m.available,
       ROUND(AVG(r.rating), 1) AS avg_rating,
       COUNT(r.id)             AS review_count
FROM   menu_items m
LEFT   JOIN reviews r ON r.pizza_id = m.id
WHERE  m.id = @pizza_id
GROUP  BY m.id;
```

`submitReview` runs the UPSERT as a single statement, then inspects
`changes()` and `lastInsertRowid` to decide its return value:

- `lastInsertRowid > 0` → `inserted`; load the new row by id and return it.
- `changes() > 0` and `lastInsertRowid` unchanged → `updated`; load the row by
  `(pizza_id, phone_number)` and return it.
- `changes() === 0` → run a one-shot diagnostic
  `SELECT EXISTS (SELECT 1 FROM menu_items WHERE id = @pizza_id)` to choose
  between `unknown_pizza` and `ineligible`. (Diagnostic SELECT is on the cold
  path only, per ADR.)

The returned `OwnReview` row carries the full `phone_number` (the customer is
asking for their own row back). List queries never select the raw column.

### Server validation — `src/server/lib/reviews-validation.ts`

```ts
export interface ParsedSubmission {
  phoneNumber: string;        // E.164-normalized
  rating: number;
  reviewText: string | null;  // trimmed; null when omitted or empty after trim
}

export type ValidationError =
  | { field: 'phone_number'; reason: 'missing' | 'invalid_format' }
  | { field: 'rating';       reason: 'missing' | 'not_integer' | 'out_of_range' }
  | { field: 'review_text';  reason: 'too_long' | 'wrong_type' };

export function parseSubmission(
  body: unknown,
): { ok: true; value: ParsedSubmission } | { ok: false; errors: ValidationError[] };
```

Rules:

- `phone_number`: required string, normalized via the existing phone
  normalizer in `src/server/lib/phone.ts`. Invalid → `invalid_format`.
- `rating`: required, must be a finite integer in `[1, 5]`. Floats (`4.5`),
  strings (`"4"`), and out-of-range integers all reject.
- `review_text`: optional. When present, must be a string. Trim leading and
  trailing whitespace. Empty after trim → store as `null` (not empty string).
  Length after trim > 200 → `too_long`.

The handler calls `parseSubmission`, returns `400` with the error list when
`ok === false`, and proceeds to `submitReview` only on success.

### HTTP endpoints — `src/server/routes/menu-item-reviews.ts`

Routes mounted under `/api/v1/menu-items` in `src/server/routes/index.ts`.

| Method | Path                                            | Purpose                          |
|--------|-------------------------------------------------|----------------------------------|
| POST   | `/api/v1/menu-items/:pizzaId/reviews`           | Submit/upsert a review           |
| GET    | `/api/v1/menu-items/:pizzaId/reviews?limit=N`   | List recent reviews for a pizza  |
| GET    | `/api/v1/menu-items/:pizzaId`                   | Single pizza + aggregate         |
| GET    | `/api/v1/menu-items?category=pizza`             | Menu list + aggregates per item  |

#### `POST /api/v1/menu-items/:pizzaId/reviews`

Request body:

```json
{ "phone_number": "+15551234567", "rating": 5, "review_text": "Best pie." }
```

Responses:

- `201 Created` — new row inserted. Body: `OwnReview`.
- `200 OK` — existing row replaced (UPSERT). Body: `OwnReview`.
- `400 Bad Request` — validation failure. Body:
  `{ "errors": ValidationError[] }`. Phone normalization failure included
  here.
- `403 Forbidden` — pizza exists but the phone has no qualifying order. Body:
  `{ "error": "ineligible", "message": "No order on file for this pizza." }`.
- `404 Not Found` — `pizzaId` does not exist in `menu_items`. Body:
  `{ "error": "unknown_pizza" }`.

The handler:

1. Coerces `pizzaId` from path to integer; non-integer → `400`.
2. Calls `parseSubmission(req.body)`; on failure returns `400` with errors.
3. Calls `submitReview({ pizzaId, ...parsed })`.
4. Maps `SubmitOutcome` to status code + body.
5. On `inserted` and `updated`, scrubs `phone_number` from any structured log
   line (per Manifest "no PII in client logs" rule); writes only `phone_tail`.

#### `GET /api/v1/menu-items/:pizzaId/reviews?limit=N`

Returns `Review[]` (note: `phone_tail` only, never `phone_number`).

- `limit` defaults to `10`, capped at `50`. Negative or non-integer → `400`.
- Unknown `pizzaId` → `200` with empty array, **not** `404`. Rationale: the
  list endpoint is shape-stable for clients that may want to render an empty
  list rather than a 404 page; the detail page itself uses
  `GET /api/v1/menu-items/:pizzaId` to detect the unknown-pizza state.

#### `GET /api/v1/menu-items/:pizzaId`

Returns `MenuItemWithAggregate` or `404` with `{ "error": "unknown_pizza" }`.

#### `GET /api/v1/menu-items?category=pizza`

Returns `MenuItemWithAggregate[]`. The `category` query param is optional. The
existing menu-list response shape is **extended** with `avg_rating` and
`review_count` columns; no other fields move.

### Client modules

#### `src/client/lib/format.ts`

```ts
export function formatRating(avg: number | null): string;
// avg === null     → throws (caller must branch on null first)
// avg === 4.3      → "4.3"
// avg === 5        → "5.0"   (always one decimal)

export function formatReviewCount(count: number): string;
// 1 → "(1)"
// 27 → "(27)"

export function formatRelativeTime(now: number, then: number): string;
// Both args in unix seconds. Stable, locale-free, deterministic for tests.
// 0–59 s    → "just now"
// 1–59 min  → "N minutes ago" (singular for 1)
// 1–23 hr   → "N hours ago"
// 1–6 days  → "N days ago"
// 7–29 days → "N weeks ago"
// 30+ days  → "N months ago" (30-day months)

export function maskPhoneTail(tail: string): string;
// tail = "4421" → "••• 4421"   (U+2022 BULLET, ASCII space, then tail)
// tail length != 4 → returns "••• ----" (defensive; SQL contract guarantees 4)
```

#### `src/client/components/RatingStars.tsx`

Read-only star glyph row. Used by `RatingBadge` and `ReviewList`.

```ts
export interface RatingStarsProps {
  value: number;         // 0..5; non-integer permitted (rounds to nearest .5 for display)
  ariaLabel: string;     // e.g. "Average rating: 4.3 out of 5"
}
```

Renders 5 SVG stars in `text-amber-500` for the filled portion and
`text-gray-300` for the empty portion. Uses the half-star CSS-clip technique
documented in Build Notes; no inline styles.

#### `src/client/components/RatingInput.tsx`

Interactive 5-button rating selector. Used by `ReviewSubmissionForm`.

```ts
export interface RatingInputProps {
  value: number | null;            // null = not yet selected
  onChange: (next: number) => void;
  disabled?: boolean;
  ariaLabel?: string;              // default: "Rating"
}
```

- Renders as a `<fieldset>` containing 5 `<button type="button">` elements.
  (Buttons, not radios, because we want explicit click handling and uniform
  Tailwind styling without resetting native radio appearance.)
- Each button has `aria-label="N stars"` and `aria-pressed={value === N}`.
- Keyboard:
  - `Tab` enters the fieldset, focuses the first or currently-selected
    button.
  - `ArrowRight` / `ArrowLeft` move focus and selection between 1..5,
    wrapping at the ends.
  - `Home` selects 1; `End` selects 5.
  - `Enter` or `Space` on the focused button confirms selection.
- Visual: filled stars in `text-amber-500`, unfilled in `text-gray-300`,
  hover pre-fills via `:hover` Tailwind classes.

#### `src/client/components/RatingBadge.tsx`

Aggregate display next to a pizza on the menu list and at the top of the
detail page.

```ts
export interface RatingBadgeProps {
  avgRating: number | null;
  reviewCount: number;
}
```

Renders one of two states:

- **Empty** (`avgRating === null` or `reviewCount === 0`):
  ```
  ┌──────────────────────────┐
  │ No reviews yet           │
  └──────────────────────────┘
  ```
  Wrapper: `inline-flex items-center text-sm text-gray-500 italic`.
- **Populated**:
  ```
  ┌────────────────────────────┐
  │ ★★★★☆  4.3  (27)           │
  └────────────────────────────┘
  ```
  Wrapper: `inline-flex items-center gap-1.5 text-sm`. Stars via
  `<RatingStars value={avgRating} ariaLabel="Average rating: 4.3 out of 5" />`,
  numeric in `font-medium text-gray-900`, count in `text-gray-500`.

The badge is itself a `<div>`, not a link. Linking is the parent's job (menu
tile wraps the entire card in a `<Link>`; see `MenuPage`).

#### `src/client/components/ReviewSubmissionForm.tsx`

Inline form attached to each pizza on the order confirmation page.

```ts
export interface ReviewSubmissionFormProps {
  pizzaId: number;
  pizzaName: string;
  phoneNumber: string;            // from the just-placed order
}
```

State machine (one-component-state, not a global store):

| State          | Trigger                                | UI                                            |
|----------------|----------------------------------------|-----------------------------------------------|
| `idle`         | initial mount                          | "Rate this pizza" button                      |
| `editing`      | user clicks "Rate this pizza"          | Rating widget + textarea + Submit + Cancel    |
| `submitting`   | user clicks Submit                     | Submit disabled, spinner glyph                |
| `saved`        | server returned 200 or 201             | "Thanks — review saved" panel + Change button |
| `error`        | server returned 4xx/5xx                | Form stays open, inline error banner          |

`Cancel` from `editing` returns to `idle` and clears the unsaved entry.
`Change` from `saved` returns to `editing` with rating + text prefilled from
the response payload.

Submission request:

```ts
fetch(`/api/v1/menu-items/${pizzaId}/reviews`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    phone_number: phoneNumber,
    rating,
    review_text: text.trim() === '' ? undefined : text.trim(),
  }),
});
```

Response handling:

- `201` → state = `saved`, store the returned `OwnReview` for the `Change`
  prefill.
- `200` → same as `201` (UI does not distinguish — both are "review saved").
- `400` → state = `error`, message: "Please check your rating and review."
- `403` → state = `error`, message: "We couldn't find an order with this
  pizza on it. Reviews are only available for pizzas you've ordered."
- `404` → state = `error`, message: "This pizza is no longer on the menu."
- 5xx / network → state = `error`, message: "Something went wrong. Please
  try again."

Layout (Tailwind only, matches the orange/red brand from `src/main.tsx`):

```
<section
  aria-labelledby={`review-${pizzaId}-heading`}
  className="rounded-md border border-orange-200 bg-white p-4"
>
  <h3 id={`review-${pizzaId}-heading`} className="text-base font-semibold">
    Rate {pizzaName}
  </h3>
  {/* state-driven body — see state machine */}
</section>
```

Validation guardrails before POST:
- Submit button disabled while `rating === null`.
- Textarea has `maxLength={200}` and a live `text.length / 200` counter
  (`text-xs text-gray-500`) below the input. Counter turns `text-red-600`
  past 180 chars.
- Empty (or whitespace-only) text is sent as omitted (no `review_text` key in
  body), per the validation spec — server accepts and stores `null`.

PII handling: `phoneNumber` is a prop, never logged via `console.*`, never
echoed into a DOM attribute, never written to a `data-*` attribute.

#### `src/client/components/ReviewList.tsx`

Rendered on the pizza detail page below the header.

```ts
export interface ReviewListProps {
  pizzaId: number;
  reviews: Review[];
}
```

When `reviews.length === 0`:

```
┌───────────────────────────────────────────────────────┐
│ No reviews yet                                        │
│                                                       │
│ Be the first — leave a review on your order           │
│ confirmation page after your next order.              │
└───────────────────────────────────────────────────────┘
```

Wrapper: `rounded-md border border-dashed border-gray-300 p-6 text-center
text-gray-600`.

When populated, renders a vertical list (`<ul className="space-y-4">`). Each
`<li>` is a card:

```
┌────────────────────────────────────────────────────┐
│ ★★★★★   ••• 4421                       2 days ago  │
│                                                    │
│ Best margherita in town. Crust was perfect.        │
└────────────────────────────────────────────────────┘
```

Per-row layout (Tailwind):

```tsx
<li className="rounded-md border border-gray-200 p-4">
  <div className="flex items-center justify-between">
    <div className="flex items-center gap-3">
      <RatingStars value={r.rating} ariaLabel={`${r.rating} stars`} />
      <span className="text-sm text-gray-500">{maskPhoneTail(r.phone_tail)}</span>
    </div>
    <time
      className="text-sm text-gray-500"
      dateTime={new Date(r.updated_at * 1000).toISOString()}
    >
      {formatRelativeTime(now, r.updated_at)}
    </time>
  </div>
  {r.review_text && (
    <p className="mt-2 text-base text-gray-800 whitespace-pre-line">
      {r.review_text}
    </p>
  )}
</li>
```

`now` comes from `Date.now() / 1000` captured **once at component mount**
(via `useMemo`) so timestamps don't tick during a single page view — matches
the Manifest's "polling or manual refresh is acceptable" stance.

#### `src/client/pages/PizzaDetailPage.tsx`

Route component for `/menu/:pizzaId`.

```ts
export function PizzaDetailPage(): JSX.Element;
```

Mount sequence:

1. Read `pizzaId` from `useParams<{ pizzaId: string }>()`.
2. If `pizzaId` is not a positive integer string, render the not-found state
   immediately (no fetch).
3. Fire two parallel fetches:
   - `GET /api/v1/menu-items/${pizzaId}` → pizza + aggregate
   - `GET /api/v1/menu-items/${pizzaId}/reviews?limit=10` → recent reviews
4. While either is pending, render a skeleton: a header placeholder and a
   list of 3 skeleton rows (Tailwind `animate-pulse` blocks).
5. When the pizza fetch returns `404`, render not-found.
6. When both succeed, render header + `<RatingBadge>` + `<ReviewList>`.
7. Header includes a back link: `<Link to="/menu">← Back to menu</Link>` in
   `text-sm text-red-700 hover:underline`.

Header layout:

```
┌──────────────────────────────────────────────────────────────┐
│ ← Back to menu                                               │
│                                                              │
│ Margherita Classic                                $12.50     │
│ Tomato, fresh mozzarella, basil.                             │
│                                                              │
│ ★★★★☆  4.3  (27)                                             │
└──────────────────────────────────────────────────────────────┘
```

Not-found state:

```
┌──────────────────────────────────────────────────────────────┐
│ Pizza not found                                              │
│                                                              │
│ We couldn't find a pizza with id "<pizzaId>".                │
│                                                              │
│ ← Back to menu                                               │
└──────────────────────────────────────────────────────────────┘
```

Wrapper: `max-w-3xl mx-auto p-6`, matching `src/main.tsx`'s `<main>` width.

#### `src/client/pages/MenuPage.tsx`

(May not yet exist — see Build Notes.) Each pizza tile wraps in a
`<Link to={\`/menu/${item.id}\`} className="block ...">` so the whole card is
clickable. The tile renders:

- Pizza name (h3)
- Description (truncated)
- Price formatted as dollars
- `<RatingBadge avgRating={item.avg_rating} reviewCount={item.review_count} />`

Pizzas with `available === false` still render their `RatingBadge` (Story 2
AC5), but the rest of the tile dims (`opacity-60`).

#### `src/client/pages/OrderConfirmationPage.tsx`

(May not yet exist — see Build Notes.) After the existing order summary, a
`<section aria-label="Rate your pizzas">` lists one
`<ReviewSubmissionForm>` per **distinct** pizza in the order (deduplicated by
`menu_item_id`). The phone number passed in is the order's `phone_number`,
already known to the page.

#### Routing — `src/main.tsx` (or wherever the `<Routes>` table lives)

Add: `<Route path="/menu/:pizzaId" element={<PizzaDetailPage />} />`

---

## Behavior

### Review submission flow

1. Customer places an order; the existing order POST returns the order body.
2. Confirmation page renders; for each distinct pizza in the order, a
   `ReviewSubmissionForm` is mounted in `idle`.
3. Customer clicks "Rate this pizza" → `editing`.
4. Customer picks 1–5 stars (required) and optionally types a review.
5. Customer clicks Submit → `submitting`; the form posts to
   `POST /api/v1/menu-items/:pizzaId/reviews`.
6. Server validates input → calls `submitReview()` → atomic UPSERT runs.
7. On `inserted` (201) or `updated` (200), form transitions to `saved` and
   shows the persisted rating + text with a "Change" button.
8. The `RatingBadge` on the menu page and the `ReviewList` on the detail
   page reflect the new submission **on next render** — there is no
   client-side cross-component invalidation in this work package; the
   server's live-aggregate query (Story 2 AC4) handles freshness.

### Aggregate rendering on the menu

1. `MenuPage` calls `GET /api/v1/menu-items?category=pizza`.
2. Each row carries `avg_rating` and `review_count` directly — no
   per-pizza fan-out (Story 2 AC3).
3. `RatingBadge` branches on `avg_rating === null || review_count === 0`
   for the empty state copy (Story 2 AC2).
4. Pizzas with `available === false` still receive a badge (Story 2 AC5);
   only the surrounding tile dims.

### Recent reviews on the detail page

1. `PizzaDetailPage` fetches pizza + reviews in parallel.
2. Reviews come back already ordered `updated_at DESC, id DESC` (the SQL
   `ORDER BY` and the covering index handle this).
3. The list renders 10 rows max (server-side limit; client does not paginate).
4. Empty state renders the static "Be the first" copy (Story 3 AC4).
5. Unknown pizza id renders the not-found state (Story 3 AC5).

### Eligibility enforcement

The server runs the atomic UPSERT once. The combination of `WHERE EXISTS`
(against `orders` + `order_items`) and `ON CONFLICT DO UPDATE` ensures:

- A customer with no qualifying order → `WHERE EXISTS` is false → 0 rows
  affected → handler returns 403.
- A customer with a qualifying order and no prior review → INSERT path → 201.
- A customer with a qualifying order and a prior review → UPDATE path → 200.
- A customer whose only qualifying order was later cancelled, but who already
  has a review → UPDATE path still succeeds, because `ON CONFLICT` doesn't
  re-check `WHERE EXISTS` against the upsert path. This is the deliberate
  "rollback is a new event, not retroactive deletion" stance from the ADR.

### Privacy boundary

- The `reviews` table stores the full `phone_number`.
- `listRecentReviewsForPizza` projects only `SUBSTR(phone_number, -4) AS
  phone_tail`. The full column is **never** selected by this function.
- `submitReview` is the only function that returns `OwnReview` (with the
  full phone number), and only as the upsert response — i.e., only to the
  customer who supplied the phone number on the same request.
- The route handler logs `phone_tail` only; the full number is scrubbed from
  any error log line.
- The client mask `••• 4421` is rendered by `maskPhoneTail`; the SQL contract
  (last 4 chars) is the only input.

---

## Edge Cases

### Server / data layer

| Case | Expected behavior |
|------|-------------------|
| `pizzaId` path segment is `"abc"` (non-integer) | 400 with `{ errors: [{ field: 'pizza_id', reason: 'invalid_format' }] }`. Never reach DB. |
| `pizzaId` is integer but does not exist | POST: 404 `{ error: 'unknown_pizza' }`. GET reviews list: 200 `[]`. GET single item: 404. |
| Phone has no order at all | UPSERT 0 rows → handler diagnostic confirms pizza exists → 403 ineligible. |
| Phone has only a `cancelled` order containing the pizza | Same as above — `WHERE o.status != 'cancelled'` excludes the row → 403. |
| Phone has a qualifying order but no review yet | INSERT path → 201. |
| Phone has a qualifying order and a prior review | UPDATE path → 200 with new values; `created_at` preserved, `updated_at` advances. |
| Phone has a prior review and the qualifying order was later cancelled | UPDATE path still succeeds (ADR-ratified). |
| `rating = 0` or `rating = 6` | 400 `out_of_range`. |
| `rating = 4.5` | 400 `not_integer`. |
| `rating = "4"` | 400 `not_integer` (strict type — string ≠ integer). |
| `review_text` is 200 chars exactly | Accepted. |
| `review_text` is 201 chars | 400 `too_long`. |
| `review_text` is `"   "` (whitespace) | Trim → empty → store `null`. 201/200. |
| `review_text` is `null` in body | Treated as omitted → store `null`. |
| `review_text` is `42` (non-string) | 400 `wrong_type`. |
| `phone_number` missing | 400 `missing`. |
| `phone_number` fails normalization | 400 `invalid_format`. |
| Concurrent submits from the same phone for the same pizza | SQLite single-writer serializes. UNIQUE constraint guarantees one row; the second submit takes the UPDATE path. |
| Aggregate query against zero reviews | `AVG` returns `NULL`, `COUNT` returns `0`. Wire shape: `avg_rating: null, review_count: 0`. Client renders empty state. |
| Aggregate query against one 5-star review | `avg_rating: 5.0, review_count: 1`. (`ROUND(AVG, 1)` ensures the `.0`.) |
| Pizza has `available = false` and 27 reviews | `listMenuItemsWithAggregates` still returns it with the aggregate. The route handler does not filter by `available`. (UI-side dimming is the only effect; reviews are not deleted — Story 2 AC5.) |
| `limit=0` on reviews list | 400 (must be ≥ 1). |
| `limit=51` | Coerced to 50; no error. (Documented; clients that want more must paginate in a future ADR.) |
| `limit=-1` | 400 `invalid_format`. |

### Client UI

| Case | Expected behavior |
|------|-------------------|
| Submission form mounted with empty `phoneNumber` prop | Submit is permanently disabled; show inline note "Order not loaded yet." (Defensive — should not occur because the page renders the form only after the order is in hand.) |
| User clicks Submit without selecting a rating | Submit button is `disabled`; click is a no-op. No client-side error banner. |
| User pastes 250 chars into the textarea | `maxLength={200}` truncates at the input; counter shows `200 / 200` in red. |
| User submits, server returns 403 | Form stays in `editing`; error banner shows the ineligible message. The rating + text are preserved (not cleared) so the user can retry with a different phone or close. |
| User submits, server returns 500 | Same as 403 but with the generic message; values preserved for retry. |
| User clicks "Change" from `saved` | Form returns to `editing`; rating + text are prefilled from the saved response. |
| User refreshes the confirmation page after a successful submission | Form remounts in `idle`. (No fetch of the user's existing review — see Behavior section. The user can re-submit; server returns 200 (UPDATE) and the form again reaches `saved`.) |
| Pizza detail page loads with a pizza that has 0 reviews | `RatingBadge` empty state in the header; `ReviewList` empty state ("Be the first") in the body. Both appear; both pull copy from the spec, not from a stale aggregate. |
| Pizza detail page loads with `pizzaId = "0"` or `pizzaId = "abc"` | Renders not-found immediately (no fetch). |
| Pizza detail page fetch fails (network) | Renders the not-found state with a "Couldn't load this pizza" subhead. (Conservative — for MVP we don't distinguish 404 from network failure in the user-visible copy.) |
| Two reviews share the same `updated_at` | Tiebreak by `id DESC` (SQL `ORDER BY updated_at DESC, id DESC`). Stable order across renders. |
| `phone_tail` is not exactly 4 chars (defensive) | `maskPhoneTail` falls back to `"••• ----"`. Never throws; never leaks. |
| Time formatting at exactly the boundary (e.g. updated 60 s ago) | "1 minutes ago" → spec uses singular "1 minute ago". `formatRelativeTime` enforces singular for `n === 1`. |

---

## Test Plan

All tests use Vitest + React Testing Library, co-located with their modules
(`<file>.test.ts` / `<file>.test.tsx`).

### `src/server/db/reviews.test.ts`

Each test boots an in-memory SQLite (`new Database(':memory:')`), runs the
schema migrations, and seeds `menu_items` + `orders` + `order_items` rows for
the scenario.

- `submitReview` inserts a new row (returns `inserted`, 201-equivalent).
- `submitReview` updates an existing row in place (returns `updated`,
  preserves `created_at`, advances `updated_at`).
- `submitReview` returns `ineligible` when the phone has no qualifying order.
- `submitReview` returns `ineligible` when the phone's only order is
  cancelled and contains the pizza.
- `submitReview` returns `unknown_pizza` when the pizza id does not exist.
- `submitReview` succeeds (UPDATE path) when the prior order was later
  cancelled but the review already exists (ADR-ratified case).
- `listRecentReviewsForPizza` returns rows ordered `updated_at DESC, id DESC`
  with `phone_tail` projected and no `phone_number` field present in the
  result objects.
- `listRecentReviewsForPizza` honors `limit` (returns at most N rows).
- `listMenuItemsWithAggregates` returns `avg_rating: null, review_count: 0`
  for a pizza with no reviews.
- `listMenuItemsWithAggregates` returns `avg_rating: 4.3, review_count: 3`
  for a pizza with three reviews of `[5, 4, 4]` (verifies `ROUND(AVG, 1)`).
- `listMenuItemsWithAggregates` includes pizzas with `available = false`.
- `getMenuItemWithAggregate` returns `null` for an unknown id.

### `src/server/lib/reviews-validation.test.ts`

- Accepts a valid body (`phone_number`, `rating`, `review_text`).
- Accepts a body without `review_text`.
- Trims whitespace-only `review_text` to `null`.
- Rejects missing `phone_number` with `field: 'phone_number', reason:
  'missing'`.
- Rejects rating `0`, rating `6`, rating `4.5`, rating `"4"`.
- Rejects `review_text` of length 201.
- Accepts `review_text` of length 200.
- Rejects `review_text` of type `number`.

### `src/server/routes/menu-item-reviews.test.ts`

Uses a real Express app mounted in-process and a seeded in-memory SQLite.

- `POST` returns 201 + the inserted row on a fresh submission.
- `POST` returns 200 + the updated row on a re-submission.
- `POST` returns 400 when the body fails validation; response shape includes
  `errors` array.
- `POST` returns 403 when the phone has no qualifying order; response is
  `{ error: 'ineligible' }`.
- `POST` returns 404 when the pizza id is unknown; response is
  `{ error: 'unknown_pizza' }`.
- `POST` response includes `phone_number` (full) on the 201 / 200 paths
  only — it must be the same value the client sent.
- `GET .../reviews` returns up to N rows; each row has `phone_tail` and no
  `phone_number`.
- `GET .../reviews?limit=51` is silently coerced to 50 rows max (assert by
  seeding 60 reviews and counting).
- `GET .../reviews?limit=0` returns 400.
- `GET .../reviews` for an unknown pizza returns 200 with `[]`.
- `GET /api/v1/menu-items/:id` returns 404 for an unknown pizza.
- `GET /api/v1/menu-items?category=pizza` returns each pizza with its
  aggregate; pizzas with no reviews carry `avg_rating: null`.

### `src/client/lib/format.test.ts`

- `formatRating(4.3) === "4.3"`.
- `formatRating(5) === "5.0"`.
- `formatReviewCount(1) === "(1)"` and `formatReviewCount(27) === "(27)"`.
- `formatRelativeTime` for boundaries: 30 s, 60 s, 59 min, 60 min, 23 hr,
  24 hr, 6 d, 7 d, 29 d, 30 d.
- `formatRelativeTime` returns `"1 minute ago"` (singular) for `n === 1`.
- `maskPhoneTail("4421") === "••• 4421"`.
- `maskPhoneTail("12") === "••• ----"` (defensive).

### `src/client/components/RatingBadge.test.tsx`

- Renders `"No reviews yet"` when `avgRating === null`.
- Renders `"No reviews yet"` when `reviewCount === 0` and `avgRating === 0`.
- Renders `"4.3"` and `"(27)"` when populated.
- Has an accessible name reflecting the average rating (`getByRole('img',
  { name: /4\.3 out of 5/ })`).

### `src/client/components/RatingInput.test.tsx`

- Renders 5 buttons with `aria-label="N stars"`.
- Click on the third button calls `onChange(3)`.
- ArrowRight on a focused button moves focus and sets the next rating.
- ArrowLeft from rating 1 wraps to rating 5.
- `Home` selects 1; `End` selects 5.
- `disabled` prop disables all buttons.

### `src/client/components/ReviewSubmissionForm.test.tsx`

Uses MSW (or a `vi.fn()` mock on `fetch`) to control responses.

- Initial state: shows "Rate this pizza" button only.
- Click "Rate this pizza" → form expands; Submit is disabled until a rating
  is picked.
- Selecting a rating enables Submit; clicking Submit posts the expected
  body shape.
- 201 response → "Thanks — review saved" panel renders with rating + text.
- 200 response → same as 201 (UI does not distinguish).
- 400 response → form stays open, error banner shows the validation message.
- 403 response → form stays open, error banner shows the ineligible copy.
- "Change" from `saved` → form reopens with rating + text prefilled.
- The `phoneNumber` prop never appears in the rendered DOM (asserted via
  `container.innerHTML.includes(phoneNumber) === false`).
- Whitespace-only review text is sent as `undefined` (no `review_text` key
  in the request body).

### `src/client/components/ReviewList.test.tsx`

- Renders the empty state when `reviews.length === 0`.
- Renders the empty-state hint pointing to the order confirmation page.
- Renders a card per review with masked phone, rating stars, and relative
  timestamp.
- Reviews without `review_text` render only the header row (no `<p>` body).
- The `<time>` element carries an ISO 8601 `dateTime` attribute.

### `src/client/pages/PizzaDetailPage.test.tsx`

- Renders skeleton while fetches are pending.
- Renders header + badge + populated `ReviewList` on the happy path.
- Renders the not-found state on a 404 from the menu-item endpoint.
- Renders the not-found state immediately when `pizzaId = "abc"` (no fetch
  fired — assert via the mock fetch counter).
- Renders the empty `ReviewList` when reviews come back as `[]`.
- The "Back to menu" link points to `/menu`.

---

## Build Notes

### Files the Builder will create

| Path | Purpose |
|------|---------|
| `src/shared/types/review.ts` | `Review`, `OwnReview`, `MenuItemWithAggregate`, `SubmitReviewRequest` |
| `src/server/db/reviews.ts` | Prepared statements + exported functions |
| `src/server/lib/reviews-validation.ts` | `parseSubmission` |
| `src/server/routes/menu-item-reviews.ts` | The four endpoints |
| `src/client/lib/format.ts` | `formatRating`, `formatReviewCount`, `formatRelativeTime`, `maskPhoneTail` |
| `src/client/components/RatingStars.tsx` | Read-only star row |
| `src/client/components/RatingInput.tsx` | Interactive 5-button rating |
| `src/client/components/RatingBadge.tsx` | Aggregate display |
| `src/client/components/ReviewSubmissionForm.tsx` | Inline form |
| `src/client/components/ReviewList.tsx` | Recent-reviews list |
| `src/client/pages/PizzaDetailPage.tsx` | `/menu/:pizzaId` route |
| Plus a `.test.ts` / `.test.tsx` co-located with each of the above. | |

### Files the Builder will inspect or extend

| Path | Action |
|------|--------|
| `src/server/db/schema.ts` | Add the `CREATE TABLE reviews` and `CREATE INDEX` statements from the ADR's Decision 1. Idempotent (`IF NOT EXISTS`). |
| `src/server/db/index.ts` (or wherever the `Database` instance is exported) | Re-use the existing connection; do not open a second one. |
| `src/server/routes/index.ts` | Mount `menu-item-reviews.ts` under `/api/v1/menu-items`. The four endpoints share the prefix; register all four. |
| `src/server/routes/menu-items.ts` (existing menu-list handler) | Replace its current SELECT (or its delegated `listMenuItems()`) with `listMenuItemsWithAggregates(category)` so the menu-list response carries `avg_rating` and `review_count` per item. The existing field set must remain unchanged. |
| `src/server/lib/phone.ts` | Re-use the existing phone normalizer; do not re-implement. |
| `src/client/pages/MenuPage.tsx` | Wrap each pizza tile in `<Link to={\`/menu/${item.id}\`}>` and add `<RatingBadge>`. Dim tiles with `available === false` via `opacity-60`; do **not** remove the badge. |
| `src/client/pages/OrderConfirmationPage.tsx` | After the existing summary, render one `<ReviewSubmissionForm>` per distinct `menu_item_id` in the order. Pass the order's `phone_number`. |
| `src/main.tsx` (or the React Router `<Routes>` table) | Add `<Route path="/menu/:pizzaId" element={<PizzaDetailPage />} />`. |
| `docs/PROJECT_MANIFEST.md` | Add the `Review` entity to the Domain Model section per Story acceptance criterion 5: keyed by surrogate id, identified by `(pizza_id, phone_number)`, related to `MenuItem` via `pizza_id` and to `Customer` (the phone-number identity) via `phone_number`. |

### Pre-existing infrastructure assumed by this design

The plan and ADR both assume the following are already in place. If the
Builder finds them missing in `src/`, they are out of scope for this work
package — file a follow-up bead instead of expanding scope:

- `src/server/db/schema.ts` with `menu_items`, `orders`, `order_items` tables.
- `src/server/lib/phone.ts` with a phone normalizer that produces a stable
  string (per the Manifest's "phone numbers are normalized + validated
  before use as identity" rule).
- `src/server/routes/menu-items.ts` with `GET /api/v1/menu-items` and
  `GET /api/v1/menu-items/:id` endpoints.
- `src/client/pages/MenuPage.tsx` and `src/client/pages/OrderConfirmationPage
  .tsx` mounted via React Router.

If any of these are missing on a clean checkout, the Builder must scaffold
them per Manifest conventions before wiring the reviews feature on top — but
the *contents* of those modules beyond what this design touches stay out of
scope.

### Conventions the Builder must follow (Manifest pull-through)

- TypeScript strict mode; no `any` without an inline justification comment.
- Tailwind utility classes only — no inline `style={}` attributes.
- Kebab-case for non-component files; PascalCase for React component files.
- API routes under `/api/v1/<resource>`.
- Route handlers stay thin — business logic lives in `src/server/lib/` and
  `src/server/db/`.
- Parameterized SQL only — no string concatenation.
- No PII (raw phone numbers) in client logs or error messages.
- Conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`,
  `chore:`).

### Out of scope (do not implement)

- Editing or deleting reviews via any UI other than re-submitting the form.
- Moderation tooling (`hidden_at`, staff hide affordance, audit log).
- Helpful / unhelpful voting on reviews.
- Spam, profanity, or rate-limit defenses beyond the validation rules above.
- Notifications about new reviews.
- Sort / filter controls on the detail page beyond "most recent first".
- Backfilling synthetic reviews or seeding fake data.
- A `GET .../reviews/mine` lookup or any "view my prior review" affordance —
  the form on the confirmation page is the only review entry point this work
  package ships.

---

## References

- Plan: [`docs/plans/pizza-ratings-and-reviews.md`](../plans/pizza-ratings-and-reviews.md)
- ADR: [`docs/architecture/pizza-ratings-and-reviews.md`](../architecture/pizza-ratings-and-reviews.md)
- Project manifest: [`docs/PROJECT_MANIFEST.md`](../PROJECT_MANIFEST.md)
- Prior design (style precedent): [`docs/designs/loyalty-points-spec.md`](./loyalty-points-spec.md)
- Prior ADR (storage philosophy precedent): [`docs/architecture/loyalty-points-storage.md`](../architecture/loyalty-points-storage.md)
- Factory wiring: [`docs/factory-wiring.md`](../factory-wiring.md)
- Source request: bead `fup-upt`
- Workflow bead: `fup-xj3`
- Designer step: `fup-1w0`
