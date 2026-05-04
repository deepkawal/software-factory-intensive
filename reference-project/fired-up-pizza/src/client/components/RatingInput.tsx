import { useRef } from "react";

export interface RatingInputProps {
  value: number | null;
  onChange: (next: number) => void;
  disabled?: boolean;
  ariaLabel?: string;
}

const STARS = [1, 2, 3, 4, 5] as const;

export function RatingInput({
  value,
  onChange,
  disabled,
  ariaLabel = "Rating",
}: RatingInputProps): JSX.Element {
  const buttonRefs = useRef<Array<HTMLButtonElement | null>>([]);

  function focusButton(index: number): void {
    const target = buttonRefs.current[index];
    if (target) target.focus();
  }

  function handleKeyDown(
    event: React.KeyboardEvent<HTMLButtonElement>,
    star: number,
  ): void {
    if (disabled) return;
    if (event.key === "ArrowRight") {
      event.preventDefault();
      const next = star === 5 ? 1 : star + 1;
      onChange(next);
      focusButton(next - 1);
      return;
    }
    if (event.key === "ArrowLeft") {
      event.preventDefault();
      const next = star === 1 ? 5 : star - 1;
      onChange(next);
      focusButton(next - 1);
      return;
    }
    if (event.key === "Home") {
      event.preventDefault();
      onChange(1);
      focusButton(0);
      return;
    }
    if (event.key === "End") {
      event.preventDefault();
      onChange(5);
      focusButton(4);
      return;
    }
  }

  return (
    <fieldset
      className="border-0 p-0 m-0 inline-flex items-center gap-1"
      aria-label={ariaLabel}
      disabled={disabled}
    >
      {STARS.map((star) => {
        const filled = value !== null && star <= value;
        return (
          <button
            key={star}
            ref={(el) => {
              buttonRefs.current[star - 1] = el;
            }}
            type="button"
            aria-label={`${star} stars`}
            aria-pressed={value === star}
            disabled={disabled}
            onClick={() => onChange(star)}
            onKeyDown={(event) => handleKeyDown(event, star)}
            className={`w-8 h-8 rounded-md ${
              filled ? "text-amber-500" : "text-gray-300"
            } hover:text-amber-400 disabled:opacity-50`}
          >
            <svg
              viewBox="0 0 24 24"
              aria-hidden="true"
              className="w-6 h-6 mx-auto fill-current"
            >
              <path d="M12 2.5l2.95 6.06 6.69.97-4.84 4.71 1.14 6.66L12 17.77l-5.94 3.13 1.14-6.66L2.36 9.53l6.69-.97L12 2.5z" />
            </svg>
          </button>
        );
      })}
    </fieldset>
  );
}
