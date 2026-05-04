import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import type {
  MenuItemWithAggregate,
  Review,
} from "../../shared/types/review";
import { RatingBadge } from "../components/RatingBadge";
import { ReviewList } from "../components/ReviewList";

type PizzaState =
  | { kind: "loading" }
  | { kind: "ready"; pizza: MenuItemWithAggregate; reviews: Review[] }
  | { kind: "not_found" };

function formatPriceCents(cents: number): string {
  return `$${(cents / 100).toFixed(2)}`;
}

export function PizzaDetailPage(): JSX.Element {
  const params = useParams<{ pizzaId: string }>();
  const pizzaIdRaw = params.pizzaId ?? "";
  const pizzaId = Number(pizzaIdRaw);
  const validId =
    pizzaIdRaw.length > 0 &&
    Number.isInteger(pizzaId) &&
    pizzaId > 0 &&
    String(pizzaId) === pizzaIdRaw;

  const [state, setState] = useState<PizzaState>(
    validId ? { kind: "loading" } : { kind: "not_found" },
  );

  useEffect(() => {
    if (!validId) return;
    let cancelled = false;
    Promise.all([
      fetch(`/api/v1/menu-items/${pizzaId}`),
      fetch(`/api/v1/menu-items/${pizzaId}/reviews?limit=10`),
    ])
      .then(async ([pizzaRes, reviewsRes]) => {
        if (cancelled) return;
        if (pizzaRes.status === 404) {
          setState({ kind: "not_found" });
          return;
        }
        if (!pizzaRes.ok || !reviewsRes.ok) {
          setState({ kind: "not_found" });
          return;
        }
        const pizza = (await pizzaRes.json()) as MenuItemWithAggregate;
        const reviews = (await reviewsRes.json()) as Review[];
        if (!cancelled) {
          setState({ kind: "ready", pizza, reviews });
        }
      })
      .catch(() => {
        if (!cancelled) setState({ kind: "not_found" });
      });
    return () => {
      cancelled = true;
    };
  }, [pizzaId, validId]);

  if (state.kind === "not_found") {
    return (
      <div className="max-w-3xl mx-auto p-6">
        <h1 className="text-2xl font-bold">Pizza not found</h1>
        <p className="mt-2 text-gray-600">
          We couldn't find a pizza with id "{pizzaIdRaw}".
        </p>
        <Link
          to="/menu"
          className="mt-4 inline-block text-sm text-red-700 hover:underline"
        >
          ← Back to menu
        </Link>
      </div>
    );
  }

  if (state.kind === "loading") {
    return (
      <div className="max-w-3xl mx-auto p-6">
        <div className="animate-pulse h-8 bg-gray-200 rounded w-1/2" />
        <ul className="mt-6 space-y-4">
          {[0, 1, 2].map((i) => (
            <li
              key={i}
              className="animate-pulse h-20 bg-gray-200 rounded"
            />
          ))}
        </ul>
      </div>
    );
  }

  const { pizza, reviews } = state;
  return (
    <div className="max-w-3xl mx-auto p-6">
      <Link
        to="/menu"
        className="text-sm text-red-700 hover:underline"
      >
        ← Back to menu
      </Link>
      <header className="mt-4 flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold">{pizza.name}</h1>
          <p className="mt-1 text-gray-600">{pizza.description}</p>
        </div>
        <span className="text-lg font-semibold">
          {formatPriceCents(pizza.base_price)}
        </span>
      </header>
      <div className="mt-3">
        <RatingBadge
          avgRating={pizza.avg_rating}
          reviewCount={pizza.review_count}
        />
      </div>
      <section className="mt-8">
        <h2 className="text-lg font-semibold">Recent reviews</h2>
        <div className="mt-3">
          <ReviewList pizzaId={pizza.id} reviews={reviews} />
        </div>
      </section>
    </div>
  );
}
