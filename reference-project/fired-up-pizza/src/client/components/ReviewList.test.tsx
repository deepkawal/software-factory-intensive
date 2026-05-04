import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import type { Review } from "../../shared/types/review";
import { ReviewList } from "./ReviewList";

function makeReview(partial: Partial<Review>): Review {
  return {
    id: 1,
    pizza_id: 1,
    phone_tail: "4421",
    rating: 5,
    review_text: "Excellent",
    created_at: 1,
    updated_at: 1,
    ...partial,
  };
}

describe("ReviewList", () => {
  it("renders the empty state when reviews is empty", () => {
    render(<ReviewList pizzaId={1} reviews={[]} />);
    expect(screen.getByText("No reviews yet")).toBeInTheDocument();
    expect(
      screen.getByText(/Be the first/),
    ).toBeInTheDocument();
  });

  it("renders a card per review with masked phone, stars, and time", () => {
    render(
      <ReviewList
        pizzaId={1}
        reviews={[makeReview({ id: 1 }), makeReview({ id: 2, phone_tail: "9999" })]}
      />,
    );
    expect(screen.getByText("••• 4421")).toBeInTheDocument();
    expect(screen.getByText("••• 9999")).toBeInTheDocument();
    expect(screen.getAllByRole("img").length).toBeGreaterThan(0);
  });

  it("omits the body paragraph when review_text is null", () => {
    render(
      <ReviewList
        pizzaId={1}
        reviews={[makeReview({ id: 1, review_text: null })]}
      />,
    );
    expect(screen.queryByText("Excellent")).not.toBeInTheDocument();
  });

  it("uses an ISO 8601 dateTime attribute", () => {
    const updatedAt = 1700000000;
    render(
      <ReviewList
        pizzaId={1}
        reviews={[makeReview({ id: 1, updated_at: updatedAt })]}
      />,
    );
    const time = document.querySelector("time");
    expect(time).not.toBeNull();
    expect(time?.getAttribute("dateTime")).toBe(
      new Date(updatedAt * 1000).toISOString(),
    );
  });
});
