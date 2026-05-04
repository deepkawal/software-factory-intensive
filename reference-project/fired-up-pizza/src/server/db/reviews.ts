import type {
  MenuItemWithAggregate,
  OwnReview,
  Review,
} from "../../shared/types/review";
import type { DB } from "./index";

export type SubmitOutcome =
  | { kind: "inserted"; row: OwnReview }
  | { kind: "updated"; row: OwnReview }
  | { kind: "ineligible" }
  | { kind: "unknown_pizza" };

export interface SubmitReviewInput {
  pizzaId: number;
  phoneNumber: string;
  rating: number;
  reviewText: string | null;
}

const UPSERT_SQL = `
INSERT INTO reviews (pizza_id, phone_number, rating, review_text, created_at, updated_at)
SELECT @pizza_id, @phone_number, @rating, @review_text, @now, @now
WHERE EXISTS (
  SELECT 1
  FROM order_items oi
  JOIN orders o ON o.id = oi.order_id
  WHERE o.phone_number = @phone_number
    AND o.status != 'cancelled'
    AND oi.menu_item_id = @pizza_id
) OR EXISTS (
  SELECT 1
  FROM reviews
  WHERE pizza_id = @pizza_id
    AND phone_number = @phone_number
)
ON CONFLICT (pizza_id, phone_number) DO UPDATE
  SET rating      = excluded.rating,
      review_text = excluded.review_text,
      updated_at  = excluded.updated_at
`;

const SELECT_OWN_BY_PAIR_SQL = `
SELECT id, pizza_id,
       SUBSTR(phone_number, -4) AS phone_tail,
       phone_number,
       rating, review_text, created_at, updated_at
FROM   reviews
WHERE  pizza_id = @pizza_id AND phone_number = @phone_number
`;

const SELECT_PIZZA_EXISTS_SQL = `
SELECT EXISTS (SELECT 1 FROM menu_items WHERE id = @pizza_id) AS present
`;

const SELECT_REVIEW_EXISTS_SQL = `
SELECT EXISTS (
  SELECT 1 FROM reviews WHERE pizza_id = @pizza_id AND phone_number = @phone_number
) AS present
`;

const LIST_RECENT_SQL = `
SELECT id, pizza_id,
       SUBSTR(phone_number, -4) AS phone_tail,
       rating, review_text, created_at, updated_at
FROM   reviews
WHERE  pizza_id = @pizza_id
ORDER  BY updated_at DESC, id DESC
LIMIT  @limit
`;

const LIST_AGGREGATE_SQL = `
SELECT m.id, m.name, m.description, m.base_price, m.category, m.available,
       ROUND(AVG(r.rating), 1) AS avg_rating,
       COUNT(r.id)             AS review_count
FROM   menu_items m
LEFT   JOIN reviews r ON r.pizza_id = m.id
WHERE  (@category IS NULL OR m.category = @category)
GROUP  BY m.id
`;

const GET_AGGREGATE_SQL = `
SELECT m.id, m.name, m.description, m.base_price, m.category, m.available,
       ROUND(AVG(r.rating), 1) AS avg_rating,
       COUNT(r.id)             AS review_count
FROM   menu_items m
LEFT   JOIN reviews r ON r.pizza_id = m.id
WHERE  m.id = @pizza_id
GROUP  BY m.id
`;

interface OwnReviewRow {
  id: number;
  pizza_id: number;
  phone_tail: string;
  phone_number: string;
  rating: number;
  review_text: string | null;
  created_at: number;
  updated_at: number;
}

interface ReviewRow {
  id: number;
  pizza_id: number;
  phone_tail: string;
  rating: number;
  review_text: string | null;
  created_at: number;
  updated_at: number;
}

interface AggregateRow {
  id: number;
  name: string;
  description: string;
  base_price: number;
  category: string;
  available: number;
  avg_rating: number | null;
  review_count: number;
}

function toAggregate(row: AggregateRow): MenuItemWithAggregate {
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    base_price: row.base_price,
    category: row.category,
    available: row.available === 1,
    avg_rating: row.avg_rating,
    review_count: row.review_count,
  };
}

export function submitReview(db: DB, input: SubmitReviewInput): SubmitOutcome {
  const reviewExistsStmt = db.prepare(SELECT_REVIEW_EXISTS_SQL);
  const upsertStmt = db.prepare(UPSERT_SQL);
  const selectByPair = db.prepare(SELECT_OWN_BY_PAIR_SQL);
  const pizzaExistsStmt = db.prepare(SELECT_PIZZA_EXISTS_SQL);

  const params = {
    pizza_id: input.pizzaId,
    phone_number: input.phoneNumber,
    rating: input.rating,
    review_text: input.reviewText,
    now: Math.floor(Date.now() / 1000),
  };

  const existedBefore =
    (reviewExistsStmt.get({
      pizza_id: input.pizzaId,
      phone_number: input.phoneNumber,
    }) as { present: number }).present === 1;

  const result = upsertStmt.run(params);

  if (result.changes === 0) {
    const presence = pizzaExistsStmt.get({ pizza_id: input.pizzaId }) as
      | { present: number }
      | undefined;
    if (!presence || presence.present === 0) {
      return { kind: "unknown_pizza" };
    }
    return { kind: "ineligible" };
  }

  const row = selectByPair.get({
    pizza_id: input.pizzaId,
    phone_number: input.phoneNumber,
  }) as OwnReviewRow | undefined;
  if (!row) {
    return { kind: "ineligible" };
  }
  return { kind: existedBefore ? "updated" : "inserted", row };
}

export function listRecentReviewsForPizza(
  db: DB,
  pizzaId: number,
  limit: number,
): Review[] {
  const stmt = db.prepare(LIST_RECENT_SQL);
  const rows = stmt.all({ pizza_id: pizzaId, limit }) as ReviewRow[];
  return rows.map((row) => ({ ...row }));
}

export function listMenuItemsWithAggregates(
  db: DB,
  category?: string,
): MenuItemWithAggregate[] {
  const stmt = db.prepare(LIST_AGGREGATE_SQL);
  const rows = stmt.all({ category: category ?? null }) as AggregateRow[];
  return rows.map(toAggregate);
}

export function getMenuItemWithAggregate(
  db: DB,
  pizzaId: number,
): MenuItemWithAggregate | null {
  const stmt = db.prepare(GET_AGGREGATE_SQL);
  const row = stmt.get({ pizza_id: pizzaId }) as AggregateRow | undefined;
  if (!row) return null;
  return toAggregate(row);
}
