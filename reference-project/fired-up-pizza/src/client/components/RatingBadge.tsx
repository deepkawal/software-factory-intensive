import { formatRating, formatReviewCount } from "../lib/format";
import { RatingStars } from "./RatingStars";

export interface RatingBadgeProps {
  avgRating: number | null;
  reviewCount: number;
}

export function RatingBadge({
  avgRating,
  reviewCount,
}: RatingBadgeProps): JSX.Element {
  if (avgRating === null || reviewCount === 0) {
    return (
      <span className="inline-flex items-center text-sm text-gray-500 italic">
        No reviews yet
      </span>
    );
  }

  const formattedRating = formatRating(avgRating);
  return (
    <span className="inline-flex items-center gap-1.5 text-sm">
      <RatingStars
        value={avgRating}
        ariaLabel={`Average rating: ${formattedRating} out of 5`}
      />
      <span className="font-medium text-gray-900">{formattedRating}</span>
      <span className="text-gray-500">{formatReviewCount(reviewCount)}</span>
    </span>
  );
}
