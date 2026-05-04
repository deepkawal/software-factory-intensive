import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { RatingInput } from "./RatingInput";

describe("RatingInput", () => {
  it("renders 5 buttons with aria-label='N stars'", () => {
    render(<RatingInput value={null} onChange={() => {}} />);
    for (let i = 1; i <= 5; i++) {
      expect(
        screen.getByRole("button", { name: `${i} stars` }),
      ).toBeInTheDocument();
    }
  });

  it("calls onChange(3) when the third button is clicked", () => {
    const onChange = vi.fn();
    render(<RatingInput value={null} onChange={onChange} />);
    fireEvent.click(screen.getByRole("button", { name: "3 stars" }));
    expect(onChange).toHaveBeenCalledWith(3);
  });

  it("ArrowRight from rating 3 selects rating 4", () => {
    const onChange = vi.fn();
    render(<RatingInput value={3} onChange={onChange} />);
    const button = screen.getByRole("button", { name: "3 stars" });
    button.focus();
    fireEvent.keyDown(button, { key: "ArrowRight" });
    expect(onChange).toHaveBeenCalledWith(4);
  });

  it("ArrowLeft from rating 1 wraps to rating 5", () => {
    const onChange = vi.fn();
    render(<RatingInput value={1} onChange={onChange} />);
    const button = screen.getByRole("button", { name: "1 stars" });
    button.focus();
    fireEvent.keyDown(button, { key: "ArrowLeft" });
    expect(onChange).toHaveBeenCalledWith(5);
  });

  it("Home selects 1 and End selects 5", () => {
    const onChange = vi.fn();
    render(<RatingInput value={3} onChange={onChange} />);
    const button = screen.getByRole("button", { name: "3 stars" });
    button.focus();
    fireEvent.keyDown(button, { key: "Home" });
    expect(onChange).toHaveBeenCalledWith(1);
    fireEvent.keyDown(button, { key: "End" });
    expect(onChange).toHaveBeenCalledWith(5);
  });

  it("disables all buttons when disabled is true", () => {
    render(<RatingInput value={null} onChange={() => {}} disabled />);
    for (let i = 1; i <= 5; i++) {
      expect(
        screen.getByRole("button", { name: `${i} stars` }),
      ).toBeDisabled();
    }
  });
});
