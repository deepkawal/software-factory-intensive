import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import type { MenuItemWithAggregate } from "../../shared/types/review";
import { RatingBadge } from "../components/RatingBadge";

function formatPriceCents(cents: number): string {
  return `$${(cents / 100).toFixed(2)}`;
}

export function MenuPage(): JSX.Element {
  const [items, setItems] = useState<MenuItemWithAggregate[] | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetch("/api/v1/menu-items?category=pizza")
      .then((res) => res.json())
      .then((data: MenuItemWithAggregate[]) => {
        if (!cancelled) setItems(data);
      })
      .catch(() => {
        if (!cancelled) setItems([]);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="max-w-4xl mx-auto p-6">
      <h1 className="text-2xl font-bold">Menu</h1>
      {items === null ? (
        <p className="mt-4 text-gray-500">Loading…</p>
      ) : items.length === 0 ? (
        <p className="mt-4 text-gray-500">No pizzas available.</p>
      ) : (
        <ul className="mt-6 grid gap-4 sm:grid-cols-2">
          {items.map((item) => (
            <li key={item.id}>
              <Link
                to={`/menu/${item.id}`}
                className={`block rounded-md border border-orange-200 bg-white p-4 hover:border-red-300 ${
                  item.available ? "" : "opacity-60"
                }`}
              >
                <div className="flex items-start justify-between gap-3">
                  <h2 className="text-lg font-semibold">{item.name}</h2>
                  <span className="text-base font-medium">
                    {formatPriceCents(item.base_price)}
                  </span>
                </div>
                <p className="mt-1 text-sm text-gray-600 line-clamp-2">
                  {item.description}
                </p>
                <div className="mt-2">
                  <RatingBadge
                    avgRating={item.avg_rating}
                    reviewCount={item.review_count}
                  />
                </div>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
