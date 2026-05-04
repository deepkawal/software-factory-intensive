import { useState } from "react";
import type { OwnReview } from "../../shared/types/review";
import { RatingInput } from "./RatingInput";

export interface ReviewSubmissionFormProps {
  pizzaId: number;
  pizzaName: string;
  phoneNumber: string;
}

type FormState =
  | { kind: "idle" }
  | { kind: "editing"; rating: number | null; text: string }
  | { kind: "submitting"; rating: number; text: string }
  | { kind: "saved"; saved: OwnReview }
  | {
      kind: "error";
      rating: number | null;
      text: string;
      message: string;
    };

const ERROR_BY_STATUS: Record<number, string> = {
  400: "Please check your rating and review.",
  403:
    "We couldn't find an order with this pizza on it. Reviews are only available for pizzas you've ordered.",
  404: "This pizza is no longer on the menu.",
};

const GENERIC_ERROR = "Something went wrong. Please try again.";

export function ReviewSubmissionForm({
  pizzaId,
  pizzaName,
  phoneNumber,
}: ReviewSubmissionFormProps): JSX.Element {
  const [state, setState] = useState<FormState>({ kind: "idle" });

  if (state.kind === "idle") {
    return (
      <section
        aria-labelledby={`review-${pizzaId}-heading`}
        className="rounded-md border border-orange-200 bg-white p-4"
      >
        <h3
          id={`review-${pizzaId}-heading`}
          className="text-base font-semibold"
        >
          Rate {pizzaName}
        </h3>
        <button
          type="button"
          className="mt-2 px-3 py-1.5 rounded-md bg-red-700 text-white text-sm hover:bg-red-800"
          onClick={() =>
            setState({ kind: "editing", rating: null, text: "" })
          }
        >
          Rate this pizza
        </button>
      </section>
    );
  }

  if (state.kind === "saved") {
    const { saved } = state;
    return (
      <section
        aria-labelledby={`review-${pizzaId}-heading`}
        className="rounded-md border border-orange-200 bg-white p-4"
      >
        <h3
          id={`review-${pizzaId}-heading`}
          className="text-base font-semibold"
        >
          Rate {pizzaName}
        </h3>
        <p className="mt-2 text-sm text-green-700">
          Thanks — review saved
        </p>
        <p className="mt-1 text-sm text-gray-700">
          You rated {saved.rating} stars
          {saved.review_text ? `: "${saved.review_text}"` : "."}
        </p>
        <button
          type="button"
          className="mt-2 text-sm text-red-700 hover:underline"
          onClick={() =>
            setState({
              kind: "editing",
              rating: saved.rating,
              text: saved.review_text ?? "",
            })
          }
        >
          Change
        </button>
      </section>
    );
  }

  const submitting = state.kind === "submitting";
  const showError = state.kind === "error" ? state.message : null;
  const rating = state.kind === "editing" || state.kind === "submitting" || state.kind === "error"
    ? state.rating
    : null;
  const text = state.kind === "editing" || state.kind === "submitting" || state.kind === "error"
    ? state.text
    : "";

  const submitDisabled =
    submitting || rating === null || phoneNumber.length === 0;

  async function handleSubmit(): Promise<void> {
    if (rating === null) return;
    setState({ kind: "submitting", rating, text });
    const trimmed = text.trim();
    const body = JSON.stringify({
      phone_number: phoneNumber,
      rating,
      ...(trimmed.length > 0 ? { review_text: trimmed } : {}),
    });
    try {
      const response = await fetch(
        `/api/v1/menu-items/${pizzaId}/reviews`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body,
        },
      );
      if (response.status === 201 || response.status === 200) {
        const saved = (await response.json()) as OwnReview;
        setState({ kind: "saved", saved });
        return;
      }
      const message = ERROR_BY_STATUS[response.status] ?? GENERIC_ERROR;
      setState({ kind: "error", rating, text, message });
    } catch {
      setState({ kind: "error", rating, text, message: GENERIC_ERROR });
    }
  }

  const counterClass =
    text.length > 180 ? "text-xs text-red-600" : "text-xs text-gray-500";

  return (
    <section
      aria-labelledby={`review-${pizzaId}-heading`}
      className="rounded-md border border-orange-200 bg-white p-4"
    >
      <h3 id={`review-${pizzaId}-heading`} className="text-base font-semibold">
        Rate {pizzaName}
      </h3>
      {phoneNumber.length === 0 && (
        <p className="mt-2 text-sm text-gray-500">Order not loaded yet.</p>
      )}
      <div className="mt-3">
        <RatingInput
          value={rating}
          disabled={submitting}
          onChange={(next) =>
            setState((prev) => {
              if (prev.kind === "editing" || prev.kind === "error") {
                return { ...prev, rating: next };
              }
              return { kind: "editing", rating: next, text };
            })
          }
        />
      </div>
      <label className="mt-3 block">
        <span className="block text-sm text-gray-700">
          Review (optional)
        </span>
        <textarea
          maxLength={200}
          rows={3}
          value={text}
          disabled={submitting}
          onChange={(event) => {
            const next = event.target.value;
            setState((prev) => {
              if (prev.kind === "editing" || prev.kind === "error") {
                return { ...prev, text: next };
              }
              return { kind: "editing", rating, text: next };
            });
          }}
          className="mt-1 w-full rounded-md border border-gray-300 p-2 text-sm"
        />
        <span className={`mt-1 block ${counterClass}`}>
          {text.length} / 200
        </span>
      </label>
      {showError && (
        <p className="mt-3 text-sm text-red-700" role="alert">
          {showError}
        </p>
      )}
      <div className="mt-3 flex items-center gap-2">
        <button
          type="button"
          disabled={submitDisabled}
          className="px-3 py-1.5 rounded-md bg-red-700 text-white text-sm hover:bg-red-800 disabled:opacity-50"
          onClick={() => {
            void handleSubmit();
          }}
        >
          {submitting ? "Submitting…" : "Submit"}
        </button>
        <button
          type="button"
          className="px-3 py-1.5 rounded-md border border-gray-300 text-sm hover:bg-gray-50"
          disabled={submitting}
          onClick={() => setState({ kind: "idle" })}
        >
          Cancel
        </button>
      </div>
    </section>
  );
}
