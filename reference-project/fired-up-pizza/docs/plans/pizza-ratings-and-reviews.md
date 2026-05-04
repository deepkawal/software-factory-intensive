# Pizza Ratings and Reviews Work Package

**Root bead:** `fup-upt`
**Workflow bead:** `fup-xj3` (mol-release-delivery)
**Planner step:** `fup-chd`
**Author agent:** planner
**Generated:** 2026-05-01

---

## Goal

Let customers rate the pizzas they have ordered (1–5 stars) and leave an
optional short text review (≤ 200 chars), then surface that signal on the menu
(average + count next to each pizza) and on a per-pizza detail page that lists
the most recent reviews. Reviews live in the existing SQLite store and are
served by the existing Express API surface (`/api/v1/*`). The feature is
limited to capturing and displaying review data — moderation tooling, edits,
and helpful-vote affordances are out of scope.

## User Stories

### Story 1 — Submit a rating + review after placing an order

**As a** customer who has just placed an order containing a pizza
**I want** to leave a 1–5 star rating and an optional short review for each
pizza I ordered
**So that** I can share my experience and help future customers choose

**Acceptance Criteria**

1. A customer can only submit a review for a `MenuItem` if their phone number
   appears on at least one `Order` whose status has reached `placed` or later
   and that order contains the pizza being reviewed.
2. Rating is an integer in `[1, 5]`. Submissions outside that range are
   rejected with a 400 response.
3. Review text is optional. When supplied, it is trimmed and validated to be
   ≤ 200 characters; longer payloads are rejected with a 400 response.
4. A customer (phone number) may have at most one review per pizza. Re-submit
   replaces the prior rating + text in place; the API treats this as an upsert
   and returns the resulting row.
5. Reviews persist across app restarts (SQLite-backed) and survive the same
   `npm install && npm run dev` boot path the rest of the app uses.
6. The submission endpoint returns a 201 (insert) or 200 (replace) with the
   stored review payload, including `pizza_id`, `phone_number`, `rating`,
   `review_text`, and `created_at` / `updated_at`.

### Story 2 — See aggregate rating on the menu

**As a** customer browsing the menu
**I want** to see the average rating and review count next to each pizza
**So that** I can quickly judge which pizzas are popular

**Acceptance Criteria**

1. Each `MenuItem` of category `pizza` on the menu page shows: a numeric
   average rating to one decimal (e.g. `4.3`), a star glyph, and the total
   review count (e.g. `(27)`).
2. Pizzas with zero reviews render an explicit "No reviews yet" affordance,
   not `0.0 (0)`.
3. The aggregate is computed server-side and returned alongside the existing
   `MenuItem` payload (no extra round trip per pizza required).
4. Aggregates reflect the database within one render — there is no cached
   aggregate that can drift more than a single page load behind the ledger.
5. A pizza that has been marked `available = false` still shows its existing
   aggregate; reviews are not deleted when availability flips.

### Story 3 — Read recent reviews on a pizza detail page

**As a** customer who tapped on a specific pizza
**I want** to read the most recent reviews other customers have left
**So that** I can decide whether to order it

**Acceptance Criteria**

1. A new route `/menu/:pizzaId` renders a detail view for a single
   `MenuItem`, including the same aggregate (average + count) and the pizza's
   existing fields (name, description, base price formatted as dollars).
2. The page lists the 10 most recent reviews for that pizza, ordered by
   `updated_at DESC`, showing rating, review text (if any), and a relative
   timestamp (e.g. "2 days ago").
3. Reviewer identity on the detail page is anonymized: only a masked tail of
   the phone number is shown (e.g. `••• 4421`), never the full number.
4. If the pizza has zero reviews, the detail page shows the same "No reviews
   yet" affordance as the menu and an inline hint pointing customers to the
   submission flow on the order confirmation screen.
5. The page handles unknown `pizzaId` with a 404-style "pizza not found"
   state rather than a server error.

## Acceptance Criteria

The feature is accepted when:

1. All Story 1, Story 2, and Story 3 acceptance criteria above pass.
2. A customer can place an order, complete review submission for each pizza
   in that order, see the aggregate on the menu page reflect their submission,
   and see their (masked) review on the pizza detail page — without leaving
   the app or refreshing more than once.
3. The full Project Manifest "Required" release-criteria checklist still
   passes: Vitest green, `tsc --noEmit` clean under strict mode, ESLint clean,
   `npm install && npm run dev` boots the app, all commits follow conventional
   commits, and a Designer spec exists in `docs/designs/`.
4. The Reviewer report contains no `High` severity findings against the
   Manifest's Spec Compliance, Style, or Security rules.
5. The Project Manifest's Domain Model section is updated to include the new
   review entity so it stays the single source of truth.

## Scope Boundary

**IN**

- New `reviews` table (or equivalent storage shape — Architect decides) keyed
  by `(pizza_id, phone_number)`.
- New Express endpoints under `/api/v1/`: at minimum a way to submit/upsert a
  review, list recent reviews for a pizza, and read aggregates as part of the
  menu payload.
- Aggregate (average + count) joined into the existing menu-list response so
  the menu page does not fan out per pizza.
- New customer-facing UI surfaces:
  - Review submission affordance reachable from the order confirmation flow,
    one form per pizza in the just-placed order.
  - Aggregate badge next to each pizza on the menu page.
  - A per-pizza detail page route showing the recent reviews list.
- Update to `docs/PROJECT_MANIFEST.md` Domain Model to register the review
  entity and its relationship to `MenuItem` and the phone-number identity.
- Vitest coverage for: validation rules, upsert behavior, aggregate math
  (including the empty case), eligibility check (phone ↔ order ↔ pizza), and
  the detail-page rendering of an empty vs. populated review list.

**OUT**

- Editing or deleting a review through any UI other than re-submission
  (upsert). No "delete my review" affordance in the MVP.
- Moderation tooling — staff cannot flag, hide, or remove reviews in this
  work package. (Acknowledged as a future feature; the storage shape should
  not preclude it but no UI ships now.)
- Helpful / unhelpful voting on reviews.
- Spam, profanity, or rate-limit defenses beyond input validation. (Mentioned
  as a follow-up risk for the Architect to acknowledge in the ADR.)
- Notifications to customers or staff about new reviews (consistent with the
  Manifest's "no SMS/push" constraint).
- Sort or filter controls on the detail page beyond "most recent first".
- Backfilling synthetic reviews or seeding fake data for the demo build.
- Multi-location / multi-tenant scoping — not relevant under the existing
  single-restaurant constraint.

## Dependencies

- Depends on the existing menu data model (`MenuItem`, with a `category` field
  identifying pizzas) and the existing order data model (`Order`,
  `OrderItem`, phone-number identity) — both already documented in the
  Project Manifest's Domain Model section.
- Depends on the Architect ADR for the storage shape of the review entity:
  table layout, primary key choice (composite vs. surrogate), how aggregates
  are computed (live `AVG` query vs. denormalized counter on `MenuItem`), and
  whether the eligibility check is enforced in SQL or in the route handler.
- Depends on the Designer spec for the customer-facing surfaces: where
  exactly the submission affordance attaches in the confirmation flow, the
  visual treatment of the aggregate badge, the layout of the detail page,
  and the masked-phone format.
- No new third-party services. The Manifest's "Services to Connect" list does
  not change; the feature stays inside the in-repo SQLite + Express boundary.

## Open Questions

1. **Review eligibility window.** Can a customer submit a review at any time
   after the order is `placed`, or only after the order reaches
   `delivered`? Defaulting to "any time after `placed`" so customers can
   review without staff having to advance status, but the Architect should
   confirm given the Manifest's pay-at-counter model.
2. **Aggregate freshness.** Live `AVG` query at request time vs. a
   denormalized `rating_sum` + `rating_count` on `MenuItem` updated on
   write. Architect decision; both meet AC3 of Story 2 if implemented
   correctly.
3. **Review identity privacy.** This plan assumes a masked-tail format
   (`••• 4421`). Designer should confirm format and whether a customer ever
   sees their own full number on their own review.
4. **Composite key vs. surrogate id.** Plan assumes uniqueness on
   `(pizza_id, phone_number)`. Architect to choose between enforcing that
   with a UNIQUE constraint on a surrogate-id row or with a composite primary
   key.
5. **Cancelled orders.** Should a customer who cancels their order before
   it is delivered still be able to leave a review for the pizzas on that
   order? Defaulting to "no — eligibility requires a non-cancelled order
   row," but Architect should ratify.
6. **Detail page entry point.** This plan introduces `/menu/:pizzaId` but
   does not require a navigation change beyond making each pizza tile on the
   menu page link to its detail page. Designer to confirm the link
   affordance.

## Handoff

The Architect should resolve:

- Storage shape for the review entity: table name, columns, key strategy
  (composite vs. surrogate id + UNIQUE), and indexes that support
  "list 10 most recent for a pizza" and "aggregate per pizza on menu list".
- Aggregate strategy: live `AVG`/`COUNT` join vs. denormalized counters on
  `MenuItem`. Pick one and document the trade-off (write amplification vs.
  read cost).
- Eligibility enforcement: SQL-side join on `orders` + `order_items` vs.
  route-handler check before insert. Pick one and explain why.
- Concrete Express endpoints and their shapes, consistent with the
  Manifest's `/api/v1/<resource>` convention.
- How review aggregates flow into the existing menu-list payload without a
  per-pizza fan-out.

The Designer should resolve:

- Submission affordance placement in the order confirmation flow (per-pizza
  inline form vs. a follow-up step), including the empty-review path.
- Visual treatment of the aggregate badge on the menu (star + numeric +
  count) and the empty-state copy for "No reviews yet".
- Layout of the per-pizza detail page (`/menu/:pizzaId`), including the
  recent-reviews list, the masked-phone presentation, the relative
  timestamp format, and the unknown-pizza state.
- Linking from the menu tile to the detail page (whole card vs. a labelled
  link) and the back-navigation affordance.
- Accessibility notes for the rating control (keyboard input, ARIA labels)
  consistent with Tailwind-only styling and no inline styles.

## References

- Manifest: `docs/PROJECT_MANIFEST.md`
- Prior plan example: `docs/plans/loyalty-points-system.md`
- Factory wiring: `docs/factory-wiring.md`
- Source request: bead `fup-upt`
