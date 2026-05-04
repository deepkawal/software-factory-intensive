import Database from "better-sqlite3";
import http from "node:http";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { createApp } from "../app";
import { applySchema } from "../db/schema";
import { setDatabaseForTesting } from "../db";

interface TestServer {
  port: number;
  close: () => Promise<void>;
}

interface ApiResponse {
  status: number;
  body: unknown;
}

interface Ctx {
  db: Database.Database;
  server: TestServer;
}

const ctx: Ctx = {
  db: undefined as unknown as Database.Database,
  server: undefined as unknown as TestServer,
};

async function startServer(): Promise<TestServer> {
  const app = createApp();
  return await new Promise((resolve, reject) => {
    const server = http.createServer(app);
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      if (typeof address === "object" && address) {
        resolve({
          port: address.port,
          close: () =>
            new Promise<void>((closeResolve) => {
              server.close(() => closeResolve());
            }),
        });
      } else {
        reject(new Error("listen returned no address"));
      }
    });
  });
}

async function request(
  method: string,
  path: string,
  body?: unknown,
): Promise<ApiResponse> {
  const response = await fetch(
    `http://127.0.0.1:${ctx.server.port}${path}`,
    {
      method,
      headers:
        body !== undefined
          ? { "Content-Type": "application/json" }
          : undefined,
      body: body !== undefined ? JSON.stringify(body) : undefined,
    },
  );
  const text = await response.text();
  let parsed: unknown = null;
  if (text.length > 0) {
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = text;
    }
  }
  return { status: response.status, body: parsed };
}

beforeEach(async () => {
  ctx.db = new Database(":memory:");
  applySchema(ctx.db);
  setDatabaseForTesting(ctx.db);
  ctx.server = await startServer();
});

afterEach(async () => {
  await ctx.server.close();
  ctx.db.close();
  setDatabaseForTesting(null);
});

function seedMenuItem(name = "Margherita"): number {
  const result = ctx.db
    .prepare(
      "INSERT INTO menu_items (name, description, base_price, category, available) VALUES (?, ?, ?, ?, ?)",
    )
    .run(name, "Tomato, mozzarella, basil.", 1250, "pizza", 1);
  return Number(result.lastInsertRowid);
}

function seedOrder(phone: string, status: string, pizzaIds: number[]): void {
  const orderId = Number(
    ctx.db
      .prepare(
        "INSERT INTO orders (phone_number, status, created_at) VALUES (?, ?, ?)",
      )
      .run(phone, status, Math.floor(Date.now() / 1000)).lastInsertRowid,
  );
  for (const pizzaId of pizzaIds) {
    ctx.db
      .prepare(
        "INSERT INTO order_items (order_id, menu_item_id, size, crust) VALUES (?, ?, 'medium', 'classic')",
      )
      .run(orderId, pizzaId);
  }
}

describe("POST /api/v1/menu-items/:pizzaId/reviews", () => {
  it("returns 201 with the inserted row on a fresh submission", async () => {
    const pizzaId = seedMenuItem();
    seedOrder("+15551234567", "placed", [pizzaId]);

    const res = await request(
      "POST",
      `/api/v1/menu-items/${pizzaId}/reviews`,
      { phone_number: "+15551234567", rating: 5, review_text: "Wonderful" },
    );

    expect(res.status).toBe(201);
    const body = res.body as Record<string, unknown>;
    expect(body.rating).toBe(5);
    expect(body.review_text).toBe("Wonderful");
    expect(body.phone_number).toBe("+15551234567");
  });

  it("returns 200 with the updated row on a re-submission", async () => {
    const pizzaId = seedMenuItem();
    seedOrder("+15551234567", "placed", [pizzaId]);

    const first = await request(
      "POST",
      `/api/v1/menu-items/${pizzaId}/reviews`,
      { phone_number: "+15551234567", rating: 5, review_text: "Good" },
    );
    expect(first.status).toBe(201);

    const second = await request(
      "POST",
      `/api/v1/menu-items/${pizzaId}/reviews`,
      { phone_number: "+15551234567", rating: 3, review_text: "Changed" },
    );
    expect(second.status).toBe(200);
    const body = second.body as Record<string, unknown>;
    expect(body.rating).toBe(3);
    expect(body.review_text).toBe("Changed");
  });

  it("returns 400 with errors on validation failure", async () => {
    const pizzaId = seedMenuItem();
    const res = await request(
      "POST",
      `/api/v1/menu-items/${pizzaId}/reviews`,
      { phone_number: "+15551234567", rating: 7 },
    );
    expect(res.status).toBe(400);
    const body = res.body as { errors: unknown[] };
    expect(Array.isArray(body.errors)).toBe(true);
    expect(body.errors.length).toBeGreaterThan(0);
  });

  it("returns 403 when phone has no qualifying order", async () => {
    const pizzaId = seedMenuItem();
    const res = await request(
      "POST",
      `/api/v1/menu-items/${pizzaId}/reviews`,
      { phone_number: "+15559999999", rating: 4 },
    );
    expect(res.status).toBe(403);
    expect(res.body).toMatchObject({ error: "ineligible" });
  });

  it("returns 404 when pizza id is unknown", async () => {
    const res = await request("POST", `/api/v1/menu-items/9999/reviews`, {
      phone_number: "+15551234567",
      rating: 4,
    });
    expect(res.status).toBe(404);
    expect(res.body).toMatchObject({ error: "unknown_pizza" });
  });

  it("echoes phone_number on the success response", async () => {
    const pizzaId = seedMenuItem();
    seedOrder("+15551234567", "placed", [pizzaId]);
    const res = await request(
      "POST",
      `/api/v1/menu-items/${pizzaId}/reviews`,
      { phone_number: "+15551234567", rating: 4 },
    );
    expect(res.status).toBe(201);
    const body = res.body as Record<string, unknown>;
    expect(body.phone_number).toBe("+15551234567");
  });
});

describe("GET /api/v1/menu-items/:pizzaId/reviews", () => {
  it("returns up to N rows with phone_tail and no phone_number", async () => {
    const pizzaId = seedMenuItem();
    seedOrder("+15551111111", "placed", [pizzaId]);
    seedOrder("+15552222222", "placed", [pizzaId]);

    await request("POST", `/api/v1/menu-items/${pizzaId}/reviews`, {
      phone_number: "+15551111111",
      rating: 5,
    });
    await request("POST", `/api/v1/menu-items/${pizzaId}/reviews`, {
      phone_number: "+15552222222",
      rating: 4,
    });

    const res = await request("GET", `/api/v1/menu-items/${pizzaId}/reviews`);
    expect(res.status).toBe(200);
    const body = res.body as Array<Record<string, unknown>>;
    expect(body.length).toBe(2);
    expect(body.every((r) => "phone_tail" in r)).toBe(true);
    expect(body.every((r) => !("phone_number" in r))).toBe(true);
  });

  it("coerces limit > 50 down to 50", async () => {
    const pizzaId = seedMenuItem();
    for (let i = 0; i < 60; i++) {
      const phone = `+1555${String(i).padStart(7, "0")}`;
      seedOrder(phone, "placed", [pizzaId]);
      await request("POST", `/api/v1/menu-items/${pizzaId}/reviews`, {
        phone_number: phone,
        rating: 4,
      });
    }
    const res = await request(
      "GET",
      `/api/v1/menu-items/${pizzaId}/reviews?limit=51`,
    );
    expect(res.status).toBe(200);
    const body = res.body as unknown[];
    expect(body.length).toBe(50);
  });

  it("returns 400 for limit=0", async () => {
    const pizzaId = seedMenuItem();
    const res = await request(
      "GET",
      `/api/v1/menu-items/${pizzaId}/reviews?limit=0`,
    );
    expect(res.status).toBe(400);
  });

  it("returns 200 with [] for an unknown pizza", async () => {
    const res = await request("GET", `/api/v1/menu-items/9999/reviews`);
    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
  });
});

describe("GET /api/v1/menu-items/:pizzaId", () => {
  it("returns 404 for an unknown pizza", async () => {
    const res = await request("GET", `/api/v1/menu-items/9999`);
    expect(res.status).toBe(404);
  });
});

describe("GET /api/v1/menu-items", () => {
  it("returns each pizza with its aggregate; empty avg is null", async () => {
    const pizzaA = seedMenuItem("A");
    seedMenuItem("B");
    seedOrder("+15551234567", "placed", [pizzaA]);
    await request("POST", `/api/v1/menu-items/${pizzaA}/reviews`, {
      phone_number: "+15551234567",
      rating: 5,
    });

    const res = await request("GET", `/api/v1/menu-items?category=pizza`);
    expect(res.status).toBe(200);
    const body = res.body as Array<Record<string, unknown>>;
    expect(body.length).toBe(2);
    const a = body.find((r) => r.name === "A");
    const b = body.find((r) => r.name === "B");
    expect(a?.avg_rating).toBe(5);
    expect(a?.review_count).toBe(1);
    expect(b?.avg_rating).toBeNull();
    expect(b?.review_count).toBe(0);
  });
});
