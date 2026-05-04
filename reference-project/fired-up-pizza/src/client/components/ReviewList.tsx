import { useMemo } from "react";
import type { Review } from "../../shared/types/review";
import { formatRelativeTime, maskPhoneTail } from "../lib/format";
import { RatingStars } from "./RatingStars";

export interface ReviewListProps {
  pizzaId: number;
  reviews: Review[];
}

export function ReviewList({ reviews }: ReviewListProps): JSX.Element {
  const now = useMemo(() => Math.floor(Date.now() / 1000), []);

  if (reviews.length === 0) {
    return (
      <div className="rounded-md border border-dashed border-gray-300 p-6 text-center text-gray-600">
        <p className="font-medium">No reviews yet</p>
        <p className="mt-2 text-sm">
          Be the first — leave a review on your order confirmation page after
          your next order.
        </p>
      </div>
    );
  }

  return (
    <ul className="space-y-4">
      {reviews.map((review) => (
        <li
          key={review.id}
          className="rounded-md border border-gray-200 p-4"
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <RatingStars
                value={review.rating}
                ariaLabel={`${review.rating} stars`}
              />
              <span className="text-sm text-gray-500">
                {maskPhoneTail(review.phone_tail)}
              </span>
            </div>
            <time
              className="text-sm text-gray-500"
              dateTime={new Date(review.updated_at * 1000).toISOString()}
            >
              {formatRelativeTime(now, review.updated_at)}
            </time>
          </div>
          {review.review_text && (
            <p className="mt-2 text-base text-gray-800 whitespace-pre-line">
              {review.review_text}
            </p>
          )}
        </li>
      ))}
    </ul>
  );
}
