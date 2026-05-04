import { normalizePhone } from "./phone";

export interface ParsedSubmission {
  phoneNumber: string;
  rating: number;
  reviewText: string | null;
}

export type ValidationError =
  | { field: "phone_number"; reason: "missing" | "invalid_format" }
  | { field: "rating"; reason: "missing" | "not_integer" | "out_of_range" }
  | { field: "review_text"; reason: "too_long" | "wrong_type" };

export type ParseResult =
  | { ok: true; value: ParsedSubmission }
  | { ok: false; errors: ValidationError[] };

const REVIEW_TEXT_MAX = 200;

export function parseSubmission(body: unknown): ParseResult {
  const errors: ValidationError[] = [];

  const obj = (body && typeof body === "object" ? body : {}) as Record<
    string,
    unknown
  >;

  const rawPhone = obj.phone_number;
  let phoneNumber = "";
  if (rawPhone === undefined || rawPhone === null || rawPhone === "") {
    errors.push({ field: "phone_number", reason: "missing" });
  } else {
    const result = normalizePhone(rawPhone);
    if (!result.ok) {
      errors.push({ field: "phone_number", reason: "invalid_format" });
    } else {
      phoneNumber = result.value;
    }
  }

  const rawRating = obj.rating;
  let rating = 0;
  if (rawRating === undefined || rawRating === null) {
    errors.push({ field: "rating", reason: "missing" });
  } else if (typeof rawRating !== "number" || !Number.isFinite(rawRating)) {
    errors.push({ field: "rating", reason: "not_integer" });
  } else if (!Number.isInteger(rawRating)) {
    errors.push({ field: "rating", reason: "not_integer" });
  } else if (rawRating < 1 || rawRating > 5) {
    errors.push({ field: "rating", reason: "out_of_range" });
  } else {
    rating = rawRating;
  }

  let reviewText: string | null = null;
  if (Object.prototype.hasOwnProperty.call(obj, "review_text")) {
    const rawText = obj.review_text;
    if (rawText === null || rawText === undefined) {
      reviewText = null;
    } else if (typeof rawText !== "string") {
      errors.push({ field: "review_text", reason: "wrong_type" });
    } else {
      const trimmed = rawText.trim();
      if (trimmed.length > REVIEW_TEXT_MAX) {
        errors.push({ field: "review_text", reason: "too_long" });
      } else if (trimmed.length === 0) {
        reviewText = null;
      } else {
        reviewText = trimmed;
      }
    }
  }

  if (errors.length > 0) {
    return { ok: false, errors };
  }

  return {
    ok: true,
    value: { phoneNumber, rating, reviewText },
  };
}
