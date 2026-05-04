## ADR-0002 · Pizza Ratings and Reviews

**Status:** Accepted
**Date:** 2026-05-01
**Supersedes:** —
**Superseded by:** —
**Work package:** [`docs/plans/pizza-ratings-and-reviews.md`](../plans/pizza-ratings-and-reviews.md)

---

## Context

The plan calls for three things: capture a 1–5 star rating + optional ≤200-char
text review per (pizza, phone) pair, surface an aggregate (average + count) on
the menu list, and render the 10 most recent reviews on a per-pizza detail
page. The feature must stay inside the existing SQLite + Express boundary, ship
an MVP without moderation tooling, and not introduce per-pizza fan-out on the
menu list.

The plan asks the Architect to resolve five things: storage shape and key
strategy, aggregate strategy (live vs denormalized), eligibility enforcement
(SQL vs route-handler), the concrete `/api/v1/*` endpoint shapes, and how the
aggregate flows into the existing menu-list payload. It also leaves six open
questions for the ADR to ratify.

Constraints pulled from `docs/PROJECT_MANIFEST.md`:

- SQLite-only via `better-sqlite3`; no external database server, no triggers
  required for the design.
- `npm install && npm run dev` boots the app — no migrations service, no cron.
- Phone number is the only customer identity; no separate `Customer` row.
- API routes follow `/api/v1/<resource>`; route handlers are thin, business
  logic lives in `src/server/lib/` or `src/server/db/`.
- Pricing logic recomputes from `MenuItem` + `Topping` at display time. The
  manifest's preference is "recompute over cache" at this scale.
- TypeScript strict mode; zod-style validation at the route boundary; no
  string-concatenated SQL; no PII in client logs.

Prior ADR: `loyalty-points-storage.md` chose an append-only ledger over a
denormalized column on `orders`, partly for audit and partly to avoid drift.
The "prefer recomputation over a cached counter at MVP scale" reasoning
applies here too.

## Options Considered

The plan surfaces three independent decisions. Each is presented below with at
least two options and tradeoffs; the chosen combination is recorded in
**Decision**.

### Decision 1 — Storage shape and key strategy

**Option A — `reviews` table with surrogate `id` + `UNIQUE(pizza_id, phone_number)`**

```sql
CREATE TABLE reviews (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  pizza_id     INTEGER NOT NULL REFERENCES menu_items(id),
  phone_number TEXT    NOT NULL,
  rating       INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  review_text  TEXT,
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL,
  UNIQUE (pizza_id, phone_number)
);
CREATE INDEX idx_reviews_pizza_recent ON reviews (pizza_id, updated_at DESC);
```

- Pros: stable integer row id makes future moderation (`hidden_at`, audit log
  links) bolt-on without re-keying; UNIQUE constraint enforces "at most one
  review per (pizza, phone)" in the database, not just in the handler;
  composite index covers both the "10 most recent for this pizza" detail-page
  query and the aggregate join.
- Cons: one extra column vs. composite-key option.

**Option B — Composite primary key `(pizza_id, phone_number)`**

- Pros: schema is one column lighter; uniqueness is implicit in the PK.
- Cons: the row has no addressable surrogate id, so any future "moderate this
  specific row" surface (admin tool, audit log foreign key, hidden flag with
  audit trail) needs to either re-introduce a surrogate id or carry the
  composite key everywhere; and the better-sqlite3 idiom in this repo prefers
  integer row ids.

**Option C — Denormalized counters on `menu_items`** (`rating_sum`, `rating_count`,
plus a separate row-per-text-review table)

- Pros: aggregate read is a single column read.
- Cons: write path has to touch two tables atomically on every submit and on
  every upsert (subtract old contribution, add new); the upsert correction
  logic is the kind of thing the prior loyalty ADR explicitly rejected as
  drift-prone; doesn't remove the need for a `reviews` table for the detail
  page anyway.

### Decision 2 — Aggregate strategy (live vs denormalized)

**Option A — Live `AVG`/`COUNT` joined into the menu-list query**

```sql
SELECT
  m.*,
  ROUND(AVG(r.rating), 1) AS avg_rating,
  COUNT(r.id)              AS review_count
FROM menu_items m
LEFT JOIN reviews r ON r.pizza_id = m.id
WHERE m.category = 'pizza'
GROUP BY m.id;
```

- Pros: no drift between source-of-truth rows and a counter; matches the
  manifest's "recompute from the source at display time" philosophy used for
  pricing; one query, no per-pizza fan-out (satisfies Story 2 AC3); the
  aggregate is always within one render of the ledger (satisfies AC4); no
  rebuild surface area.
- Cons: read cost grows with review count. At the MVP scale (single
  restaurant, low-tens of pizzas, thousands of reviews max) this is well under
  the manifest's 200ms read budget; revisit only if the menu-list endpoint
  starts to exceed it.

**Option B — Denormalized `rating_sum` + `rating_count` on `menu_items`**

- Pros: aggregate read is two column reads; constant-time regardless of
  review volume.
- Cons: write amplification — every upsert must subtract the prior rating's
  contribution and add the new one in the same transaction as the `reviews`
  insert; same drift class the loyalty ADR rejected; if the counters ever
  diverge from the ledger, the only way to recover is a full recompute over
  the `reviews` table, which is exactly the work Option A pays incrementally
  on read.

### Decision 3 — Eligibility enforcement

**Option A — Atomic conditional upsert (`INSERT ... SELECT ... WHERE EXISTS`)**

The handler runs a single SQL statement that inserts only if the eligibility
predicate holds against `orders` + `order_items`:

```sql
INSERT INTO reviews (pizza_id, phone_number, rating, review_text, created_at, updated_at)
SELECT :pizza_id, :phone, :rating, :text, :now, :now
WHERE EXISTS (
  SELECT 1
  FROM order_items oi
  JOIN orders o ON o.id = oi.order_id
  WHERE o.phone_number = :phone
    AND o.status != 'cancelled'
    AND oi.menu_item_id = :pizza_id
)
ON CONFLICT (pizza_id, phone_number) DO UPDATE
  SET rating      = excluded.rating,
      review_text = excluded.review_text,
      updated_at  = excluded.updated_at;
```

If `INSERT` affects zero rows, the handler returns 403 (no eligible order).

- Pros: atomic — no TOCTOU window between check and write; one statement;
  thin handler; uses `better-sqlite3`'s prepared-statement path.
- Cons: error attribution is one indirection — the handler infers "ineligible"
  from `changes() === 0`. Mitigated by the handler running a follow-up
  diagnostic `SELECT EXISTS` only on the zero-rows path to choose between 403
  (ineligible) and 404 (unknown pizza), which keeps the hot path single-shot.

**Option B — Two-step: handler runs `SELECT EXISTS`, then INSERT/UPSERT**

- Pros: simpler error attribution; clear control flow.
- Cons: two round trips per submission (negligible at our scale, so this is
  not the deciding factor); a TOCTOU window where an order could be
  cancelled between the check and the write. At MVP scale and with the
  linear status flow this race is acceptable, but Option A removes it for
  free.

**Option C — SQLite trigger that aborts on ineligibility**

- Pros: enforcement lives at the schema layer.
- Cons: triggers add a hidden control-flow surface that isn't exercised by
  Vitest the same way handler code is; the manifest pushes business logic
  into `src/server/lib/` and `src/server/db/`, not into trigger bodies.

### Decision 4 — Endpoint shape and aggregate delivery

**Option A — Nested resource under `menu-items`** (chosen direction)

- `POST   /api/v1/menu-items/:pizzaId/reviews` — submit/upsert
- `GET    /api/v1/menu-items/:pizzaId/reviews?limit=10` — recent reviews
- `GET    /api/v1/menu-items/:pizzaId` — single pizza with aggregate
- `GET    /api/v1/menu-items` — extended to include `avg_rating` + `review_count`

- Pros: keeps "review of pizza" lexically attached to its parent `menu-item`;
  matches the existing `/api/v1/<resource>` convention; aggregate delivery on
  the existing menu-list endpoint avoids fan-out (Story 2 AC3).

**Option B — Top-level `/api/v1/reviews`** (e.g. `POST /api/v1/reviews` with
`{pizza_id, phone_number, rating}`)

- Pros: flatter resource graph.
- Cons: the resource is meaningless without the pizza context; aggregates
  still have to live on the menu-list endpoint anyway, so this only saves
  one path segment at the cost of weaker coupling.

## Decision

**Adopted (one decision per option set above):**

1. **Storage:** Option A — `reviews` table with surrogate `id INTEGER PRIMARY
   KEY AUTOINCREMENT`, `UNIQUE(pizza_id, phone_number)`, and a covering
   `(pizza_id, updated_at DESC)` index.
2. **Aggregate strategy:** Option A — live `ROUND(AVG(rating), 1)` /
   `COUNT(reviews.id)` joined into the menu-list and detail queries. NULL
   average is preserved on the wire (not coerced to `0.0`) so the client can
   render the explicit "No reviews yet" empty state required by Story 2 AC2.
3. **Eligibility:** Option A — atomic conditional UPSERT
   (`INSERT ... SELECT ... WHERE EXISTS ... ON CONFLICT DO UPDATE`). The
   handler returns 201 on insert, 200 on update, 403 on ineligible, 400 on
   validation failure, 404 on unknown pizza.
4. **Endpoints:** Option A — nested under `/api/v1/menu-items/:pizzaId/reviews`,
   with the aggregate piggybacked on the existing menu-list payload to avoid
   fan-out.

**Open questions ratified (from the plan):**

1. **Eligibility window:** any order with `status != 'cancelled'` is eligible
   — including `placed`. The pay-at-counter, no-SMS-no-push manifest
   constraint means staff may not advance status promptly, and gating on
   `delivered` punishes customers for that hygiene gap.
2. **Aggregate freshness:** live (Decision 2 above).
3. **Identity privacy on the wire:** the API never returns the raw phone
   number on the reviews-list endpoint. The SQL projection emits a
   `phone_tail` field — `SUBSTR(phone_number, -4)` — and the client renders
   it with the bullet prefix (`••• 4421`). The submission endpoint echoes
   back `phone_number` only on the request the customer just made (their
   own number) so the confirmation flow can still display "review submitted
   by you"; it does not appear on any list response. The Designer owns the
   visual mask format; the API guarantees the tail-only projection on
   list-style responses.
4. **Key strategy:** surrogate id + UNIQUE (Decision 1 above).
5. **Cancelled orders:** eligibility excludes orders with `status =
   'cancelled'` at submit time. Once accepted, a review persists even if the
   order is later cancelled — consistent with the loyalty ADR's "rollback is
   a new event, not retroactive deletion" pattern. Future moderation tooling
   (out of scope) is the place to add a "hide review for cancelled order"
   policy if one is ever needed.
6. **Detail page entry point:** route is `/menu/:pizzaId`, served by the same
   SPA shell. Visual entry point (whole-card vs. labelled link) is the
   Designer's call.

## Consequences

### Positive

- One new table, one new index, no schema changes to `menu_items` or `orders`.
- Aggregate cannot drift from the ledger because there is no second copy.
- Atomic conditional upsert removes the eligibility race without needing a
  trigger or a second round trip on the hot path.
- Future moderation, hide-by-staff, or audit-log features can attach to the
  surrogate `reviews.id` without re-keying.
- Menu-list endpoint stays single-query — Story 2 AC3 (no per-pizza fan-out)
  is met by construction.
- API responses on list-style endpoints never carry a full phone number,
  satisfying the manifest's "no PII in client logs / error messages" rule on
  the wire as well as on the surface.

### Negative

- Live aggregate read scales linearly with review count. At MVP scale this is
  inside the 200ms manifest budget; if the menu-list endpoint ever crosses
  it, the next ADR introduces denormalized counters or a rollup table — but
  this is not done preemptively.
- Error attribution on the upsert path requires one diagnostic follow-up
  query to distinguish 403 (ineligible) from 404 (unknown pizza). This is on
  the cold path only.

### Neutral

- Updates to `docs/PROJECT_MANIFEST.md`'s Domain Model section (per Story
  acceptance criterion 5) should add the `Review` entity: keyed by surrogate
  id, identified by `(pizza_id, phone_number)`, related to `MenuItem` via
  `pizza_id` and to `Customer` (the phone-number identity) via
  `phone_number`. The Coder owns that edit; the shape is fixed here.

## Risks

- **Spam, profanity, and rate-limit defenses are explicitly out of scope.**
  The plan flags this; this ADR ratifies it. A future ADR should cover at
  minimum: per-phone submission rate limiting, profanity filter, and a
  staff-facing "hide" affordance. The current schema does not preclude any
  of these (surrogate id + nullable `hidden_at` is the obvious extension).
- **Phone-number disclosure via masked tail.** If phone numbers are not
  normalized before storage, the last-4 mask could leak structure (e.g.
  reveal a country code that's also the customer's local prefix). The
  manifest already requires phone normalization at the validation boundary
  (Security review standard). Coder must keep `phone_tail` derived in SQL,
  not in the client, so a misuse can't bypass the projection.
- **Composite-index size on detail page query.** The `(pizza_id, updated_at
  DESC)` index supports the "10 most recent" query directly. If, in the
  future, sort/filter controls are added to the detail page (currently out
  of scope), the index may need to be revisited.
- **Order status churn vs. review acceptance.** A customer who places an
  order, submits a review, then has the order cancelled by staff keeps the
  review. The plan's "rollback is acknowledged as a future feature" stance
  is preserved here; this is a deliberate consequence, not a gap.

## References

- Work package: [`docs/plans/pizza-ratings-and-reviews.md`](../plans/pizza-ratings-and-reviews.md)
- Project manifest: [`docs/PROJECT_MANIFEST.md`](../PROJECT_MANIFEST.md)
- Prior ADR (storage philosophy precedent): [`docs/architecture/loyalty-points-storage.md`](./loyalty-points-storage.md)
- Factory wiring: [`docs/factory-wiring.md`](../factory-wiring.md)
- Source request: bead `fup-upt`
- Workflow bead: `fup-xj3`
- Architect step: `fup-92g`
