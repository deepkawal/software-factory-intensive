import { describe, expect, it } from "vitest";
import { parseSubmission } from "./reviews-validation";

describe("parseSubmission", () => {
  it("accepts a valid body", () => {
    const result = parseSubmission({
      phone_number: "+15551234567",
      rating: 5,
      review_text: "Great pie",
    });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.phoneNumber).toBe("+15551234567");
      expect(result.value.rating).toBe(5);
      expect(result.value.reviewText).toBe("Great pie");
    }
  });

  it("accepts a body without review_text", () => {
    const result = parseSubmission({
      phone_number: "+15551234567",
      rating: 4,
    });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.reviewText).toBeNull();
    }
  });

  it("trims whitespace-only review_text to null", () => {
    const result = parseSubmission({
      phone_number: "+15551234567",
      rating: 4,
      review_text: "   ",
    });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.reviewText).toBeNull();
    }
  });

  it("rejects missing phone_number", () => {
    const result = parseSubmission({ rating: 5 });
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.errors).toEqual(
        expect.arrayContaining([
          { field: "phone_number", reason: "missing" },
        ]),
      );
    }
  });

  it("rejects rating 0", () => {
    const result = parseSubmission({
      phone_number: "+15551234567",
      rating: 0,
    });
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.errors).toEqual(
        expect.arrayContaining([
          { field: "rating", reason: "out_of_range" },
        ]),
      );
    }
  });

  it("rejects rating 6", () => {
    const result = parseSubmission({
      phone_number: "+15551234567",
      rating: 6,
    });
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.errors).toEqual(
        expect.arrayContaining([
          { field: "rating", reason: "out_of_range" },
        ]),
      );
    }
  });

  it("rejects rating 4.5", () => {
    const result = parseSubmission({
      phone_number: "+15551234567",
      rating: 4.5,
    });
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.errors).toEqual(
        expect.arrayContaining([
          { field: "rating", reason: "not_integer" },
        ]),
      );
    }
  });

  it("rejects rating as string", () => {
    const result = parseSubmission({
      phone_number: "+15551234567",
      rating: "4",
    });
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.errors).toEqual(
        expect.arrayContaining([
          { field: "rating", reason: "not_integer" },
        ]),
      );
    }
  });

  it("rejects review_text of length 201", () => {
    const result = parseSubmission({
      phone_number: "+15551234567",
      rating: 4,
      review_text: "a".repeat(201),
    });
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.errors).toEqual(
        expect.arrayContaining([
          { field: "review_text", reason: "too_long" },
        ]),
      );
    }
  });

  it("accepts review_text of length 200", () => {
    const result = parseSubmission({
      phone_number: "+15551234567",
      rating: 4,
      review_text: "a".repeat(200),
    });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.reviewText?.length).toBe(200);
    }
  });

  it("rejects review_text of type number", () => {
    const result = parseSubmission({
      phone_number: "+15551234567",
      rating: 4,
      review_text: 42,
    });
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.errors).toEqual(
        expect.arrayContaining([
          { field: "review_text", reason: "wrong_type" },
        ]),
      );
    }
  });
});
