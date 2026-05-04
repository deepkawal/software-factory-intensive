export interface RatingStarsProps {
  value: number;
  ariaLabel: string;
}

const STAR_PATH =
  "M12 2.5l2.95 6.06 6.69.97-4.84 4.71 1.14 6.66L12 17.77l-5.94 3.13 1.14-6.66L2.36 9.53l6.69-.97L12 2.5z";

export function RatingStars({ value, ariaLabel }: RatingStarsProps): JSX.Element {
  const clamped = Math.max(0, Math.min(5, value));
  const filledStars = Math.round(clamped);

  return (
    <span
      role="img"
      aria-label={ariaLabel}
      className="inline-flex items-center"
    >
      {[1, 2, 3, 4, 5].map((position) => {
        const filled = position <= filledStars;
        return (
          <svg
            key={position}
            viewBox="0 0 24 24"
            aria-hidden="true"
            className={`w-4 h-4 fill-current ${
              filled ? "text-amber-500" : "text-gray-300"
            }`}
          >
            <path d={STAR_PATH} />
          </svg>
        );
      })}
    </span>
  );
}
