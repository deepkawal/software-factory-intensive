import { render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { PizzaDetailPage } from "./PizzaDetailPage";

interface MockResponse {
  status: number;
  body: unknown;
}

function mockFetch(
  responses: Record<string, MockResponse | (() => MockResponse)>,
): ReturnType<typeof vi.fn> {
  const fn = vi.fn(async (url: RequestInfo | URL) => {
    const key = String(url);
    const match = Object.keys(responses).find((path) => key.includes(path));
    if (!match) {
      return new Response("not found", { status: 404 });
    }
    const entry = responses[match]!;
    const value = typeof entry === "function" ? entry() : entry;
    return new Response(JSON.stringify(value.body), {
      status: value.status,
      headers: { "Content-Type": "application/json" },
    });
  });
  vi.spyOn(globalThis, "fetch").mockImplementation(fn as unknown as typeof fetch);
  return fn;
}

function renderAt(path: string): void {
  render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route path="/menu/:pizzaId" element={<PizzaDetailPage />} />
        <Route path="/menu" element={<div>menu page</div>} />
      </Routes>
    </MemoryRouter>,
  );
}

beforeEach(() => {
  vi.restoreAllMocks();
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("PizzaDetailPage", () => {
  it("renders header + badge + populated reviews on the happy path", async () => {
    mockFetch({
      "/api/v1/menu-items/1/reviews": {
        status: 200,
        body: [
          {
            id: 1,
            pizza_id: 1,
            phone_tail: "4421",
            rating: 5,
            review_text: "Wonderful",
            created_at: 1,
            updated_at: Math.floor(Date.now() / 1000) - 60,
          },
        ],
      },
      "/api/v1/menu-items/1": {
        status: 200,
        body: {
          id: 1,
          name: "Margherita",
          description: "Tomato, mozzarella, basil.",
          base_price: 1250,
          category: "pizza",
          available: true,
          avg_rating: 5,
          review_count: 1,
        },
      },
    });

    renderAt("/menu/1");
    await waitFor(() =>
      expect(screen.getByText("Margherita")).toBeInTheDocument(),
    );
    expect(screen.getByText("$12.50")).toBeInTheDocument();
    expect(screen.getByText("Wonderful")).toBeInTheDocument();
    expect(screen.getByText("← Back to menu")).toBeInTheDocument();
  });

  it("renders not-found state when the pizza endpoint returns 404", async () => {
    mockFetch({
      "/api/v1/menu-items/1/reviews": { status: 200, body: [] },
      "/api/v1/menu-items/1": {
        status: 404,
        body: { error: "unknown_pizza" },
      },
    });
    renderAt("/menu/1");
    await waitFor(() =>
      expect(screen.getByText("Pizza not found")).toBeInTheDocument(),
    );
  });

  it("renders not-found immediately for non-integer pizza ids without firing fetch", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    renderAt("/menu/abc");
    expect(screen.getByText("Pizza not found")).toBeInTheDocument();
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it("renders the empty review list when reviews is []", async () => {
    mockFetch({
      "/api/v1/menu-items/1/reviews": { status: 200, body: [] },
      "/api/v1/menu-items/1": {
        status: 200,
        body: {
          id: 1,
          name: "Margherita",
          description: "Tomato, mozzarella, basil.",
          base_price: 1250,
          category: "pizza",
          available: true,
          avg_rating: null,
          review_count: 0,
        },
      },
    });
    renderAt("/menu/1");
    await waitFor(() =>
      expect(screen.getByText(/Be the first/)).toBeInTheDocument(),
    );
  });
});
