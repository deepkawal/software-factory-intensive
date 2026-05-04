import Database from "better-sqlite3";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { applySchema } from "./schema";
import {
  getMenuItemWithAggregate,
  listMenuItemsWithAggregates,
  listRecentReviewsForPizza,
  submitReview,
} from "./reviews";

interface Ctx {
  db: Database.Database;
}

const ctx: Ctx = { db: undefined as unknown as Database.Database };

beforeEach(() => {
  ctx.db = new Database(":memory:");
  applySchema(ctx.db);
});

afterEach(() => {
  ctx.db.close();
});

function seedMenuItem(
  db: Database.Database,
  partial: Partial<{
    name: string;
    description: string;
    base_price: number;
    category: string;
    available: number;
  }> = {},
): number {
  const stmt = db.prepare(
    "INSERT INTO menu_items (name, description, base_price, category, available) VALUES (?, ?, ?, ?, ?)",
  );
  const result = stmt.run(
    partial.name ?? "Margherita",
    partial.description ?? "Tomato, mozzarella, basil.",
    partial.base_price ?? 1250,
    partial.category ?? "pizza",
    partial.available ?? 1,
  );
  return Number(result.lastInsertRowid);
}

function seedOrder(
  db: Database.Database,
  phone: string,
  status: string,
  pizzaIds: number[],
): number {
  const orderStmt = db.prepare(
    "INSERT INTO orders (phone_number, status, created_at) VALUES (?, ?, ?)",
  );
  const orderId = Number(
    orderStmt.run(phone, status, Math.floor(Date.now() / 1000)).lastInsertRowid,
  );
  const itemStmt = db.prepare(
    "INSERT INTO order_items (order_id, menu_item_id, size, crust) VALUES (?, ?, 'medium', 'classic')",
  );
  for (const pizzaId of pizzaIds) {
    itemStmt.run(orderId, pizzaId);
  }
  return orderId;
}

describe("submitReview", () => {
  it("inserts a new row when the customer has a qualifying order", () => {
    const pizzaId = seedMenuItem(ctx.db);
    seedOrder(ctx.db, "+15551234567", "placed", [pizzaId]);

    const outcome = submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15551234567",
      rating: 5,
      reviewText: "Loved it",
    });

    expect(outcome.kind).toBe("inserted");
    if (outcome.kind === "inserted") {
      expect(outcome.row.rating).toBe(5);
      expect(outcome.row.review_text).toBe("Loved it");
      expect(outcome.row.phone_number).toBe("+15551234567");
      expect(outcome.row.phone_tail).toBe("4567");
    }
  });

  it("updates an existing row in place, preserving created_at", () => {
    const pizzaId = seedMenuItem(ctx.db);
    seedOrder(ctx.db, "+15551234567", "placed", [pizzaId]);

    const first = submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15551234567",
      rating: 4,
      reviewText: "Good",
    });
    expect(first.kind).toBe("inserted");
    const initialCreatedAt =
      first.kind === "inserted" ? first.row.created_at : 0;

    const second = submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15551234567",
      rating: 2,
      reviewText: "Changed my mind",
    });

    expect(second.kind).toBe("updated");
    if (second.kind === "updated") {
      expect(second.row.rating).toBe(2);
      expect(second.row.review_text).toBe("Changed my mind");
      expect(second.row.created_at).toBe(initialCreatedAt);
      expect(second.row.updated_at).toBeGreaterThanOrEqual(initialCreatedAt);
    }
  });

  it("returns ineligible when the phone has no qualifying order", () => {
    const pizzaId = seedMenuItem(ctx.db);
    const outcome = submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15559999999",
      rating: 3,
      reviewText: null,
    });
    expect(outcome.kind).toBe("ineligible");
  });

  it("returns ineligible when the only order containing the pizza is cancelled", () => {
    const pizzaId = seedMenuItem(ctx.db);
    seedOrder(ctx.db, "+15551234567", "cancelled", [pizzaId]);
    const outcome = submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15551234567",
      rating: 4,
      reviewText: null,
    });
    expect(outcome.kind).toBe("ineligible");
  });

  it("returns unknown_pizza for a missing menu_items id", () => {
    const outcome = submitReview(ctx.db, {
      pizzaId: 9999,
      phoneNumber: "+15551234567",
      rating: 4,
      reviewText: null,
    });
    expect(outcome.kind).toBe("unknown_pizza");
  });

  it("succeeds via UPDATE when the qualifying order was later cancelled", () => {
    const pizzaId = seedMenuItem(ctx.db);
    const orderId = seedOrder(ctx.db, "+15551234567", "placed", [pizzaId]);

    const first = submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15551234567",
      rating: 5,
      reviewText: "Awesome",
    });
    expect(first.kind).toBe("inserted");

    ctx.db
      .prepare("UPDATE orders SET status = 'cancelled' WHERE id = ?")
      .run(orderId);

    const second = submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15551234567",
      rating: 3,
      reviewText: "On reflection",
    });
    expect(second.kind).toBe("updated");
  });
});

describe("listRecentReviewsForPizza", () => {
  it("orders rows by updated_at DESC, then id DESC", () => {
    const pizzaId = seedMenuItem(ctx.db);
    seedOrder(ctx.db, "+15551111111", "placed", [pizzaId]);
    seedOrder(ctx.db, "+15552222222", "placed", [pizzaId]);
    seedOrder(ctx.db, "+15553333333", "placed", [pizzaId]);

    submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15551111111",
      rating: 5,
      reviewText: "First",
    });
    submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15552222222",
      rating: 4,
      reviewText: "Second",
    });
    submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15553333333",
      rating: 3,
      reviewText: "Third",
    });

    const reviews = listRecentReviewsForPizza(ctx.db, pizzaId, 10);
    expect(reviews.length).toBe(3);
    expect(reviews[0]!.review_text).toBe("Third");
    expect(reviews[2]!.review_text).toBe("First");
    expect(reviews.every((r) => "phone_tail" in r)).toBe(true);
    expect(reviews.every((r) => !("phone_number" in r))).toBe(true);
  });

  it("honors the limit parameter", () => {
    const pizzaId = seedMenuItem(ctx.db);
    for (let i = 0; i < 5; i++) {
      const phone = `+1555000000${i}`;
      seedOrder(ctx.db, phone, "placed", [pizzaId]);
      submitReview(ctx.db, {
        pizzaId,
        phoneNumber: phone,
        rating: 3,
        reviewText: `Review ${i}`,
      });
    }
    const reviews = listRecentReviewsForPizza(ctx.db, pizzaId, 2);
    expect(reviews.length).toBe(2);
  });
});

describe("listMenuItemsWithAggregates", () => {
  it("returns avg_rating: null and review_count: 0 for a pizza with no reviews", () => {
    const pizzaId = seedMenuItem(ctx.db, { name: "Pepperoni" });
    const items = listMenuItemsWithAggregates(ctx.db, "pizza");
    expect(items.length).toBe(1);
    expect(items[0]!.id).toBe(pizzaId);
    expect(items[0]!.avg_rating).toBeNull();
    expect(items[0]!.review_count).toBe(0);
  });

  it("returns ROUND(AVG, 1) when there are reviews", () => {
    const pizzaId = seedMenuItem(ctx.db);
    for (let i = 0; i < 3; i++) {
      const phone = `+1555100000${i}`;
      seedOrder(ctx.db, phone, "placed", [pizzaId]);
    }
    submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15551000000",
      rating: 5,
      reviewText: null,
    });
    submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15551000001",
      rating: 4,
      reviewText: null,
    });
    submitReview(ctx.db, {
      pizzaId,
      phoneNumber: "+15551000002",
      rating: 4,
      reviewText: null,
    });

    const items = listMenuItemsWithAggregates(ctx.db, "pizza");
    expect(items[0]!.avg_rating).toBe(4.3);
    expect(items[0]!.review_count).toBe(3);
  });

  it("includes pizzas with available = false", () => {
    seedMenuItem(ctx.db, { name: "Discontinued", available: 0 });
    const items = listMenuItemsWithAggregates(ctx.db, "pizza");
    expect(items.length).toBe(1);
    expect(items[0]!.available).toBe(false);
  });
});

describe("getMenuItemWithAggregate", () => {
  it("returns null for an unknown id", () => {
    expect(getMenuItemWithAggregate(ctx.db, 9999)).toBeNull();
  });

  it("returns the row with aggregate for an existing pizza", () => {
    const pizzaId = seedMenuItem(ctx.db);
    const item = getMenuItemWithAggregate(ctx.db, pizzaId);
    expect(item).not.toBeNull();
    expect(item!.id).toBe(pizzaId);
    expect(item!.avg_rating).toBeNull();
    expect(item!.review_count).toBe(0);
  });
});
