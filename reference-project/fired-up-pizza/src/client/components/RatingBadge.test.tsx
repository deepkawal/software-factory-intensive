import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { RatingBadge } from "./RatingBadge";

describe("RatingBadge", () => {
  it("renders 'No reviews yet' when avgRating is null", () => {
    render(<RatingBadge avgRating={null} reviewCount={0} />);
    expect(screen.getByText("No reviews yet")).toBeInTheDocument();
  });

  it("renders 'No reviews yet' when reviewCount is 0", () => {
    render(<RatingBadge avgRating={0} reviewCount={0} />);
    expect(screen.getByText("No reviews yet")).toBeInTheDocument();
  });

  it("renders the rating and count when populated", () => {
    render(<RatingBadge avgRating={4.3} reviewCount={27} />);
    expect(screen.getByText("4.3")).toBeInTheDocument();
    expect(screen.getByText("(27)")).toBeInTheDocument();
  });

  it("exposes an accessible name on the stars", () => {
    render(<RatingBadge avgRating={4.3} reviewCount={27} />);
    expect(
      screen.getByRole("img", { name: /4\.3 out of 5/ }),
    ).toBeInTheDocument();
  });
});
