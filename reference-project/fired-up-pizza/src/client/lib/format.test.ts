import { describe, expect, it } from "vitest";
import {
  formatRating,
  formatRelativeTime,
  formatReviewCount,
  maskPhoneTail,
} from "./format";

describe("formatRating", () => {
  it("formats 4.3 as '4.3'", () => {
    expect(formatRating(4.3)).toBe("4.3");
  });

  it("formats 5 as '5.0'", () => {
    expect(formatRating(5)).toBe("5.0");
  });

  it("throws when avg is null", () => {
    expect(() => formatRating(null)).toThrow();
  });
});

describe("formatReviewCount", () => {
  it("wraps the count in parentheses", () => {
    expect(formatReviewCount(1)).toBe("(1)");
    expect(formatReviewCount(27)).toBe("(27)");
  });
});

describe("formatRelativeTime", () => {
  const now = 10_000_000;

  it("returns 'just now' under 60 seconds", () => {
    expect(formatRelativeTime(now, now - 30)).toBe("just now");
  });

  it("returns '1 minute ago' at 60 seconds", () => {
    expect(formatRelativeTime(now, now - 60)).toBe("1 minute ago");
  });

  it("returns '59 minutes ago' at 59 minutes", () => {
    expect(formatRelativeTime(now, now - 59 * 60)).toBe("59 minutes ago");
  });

  it("returns '1 hour ago' at 60 minutes", () => {
    expect(formatRelativeTime(now, now - 60 * 60)).toBe("1 hour ago");
  });

  it("returns '23 hours ago' at 23 hours", () => {
    expect(formatRelativeTime(now, now - 23 * 60 * 60)).toBe(
      "23 hours ago",
    );
  });

  it("returns '1 day ago' at 24 hours", () => {
    expect(formatRelativeTime(now, now - 24 * 60 * 60)).toBe("1 day ago");
  });

  it("returns '6 days ago' at 6 days", () => {
    expect(formatRelativeTime(now, now - 6 * 24 * 60 * 60)).toBe(
      "6 days ago",
    );
  });

  it("returns '1 week ago' at 7 days", () => {
    expect(formatRelativeTime(now, now - 7 * 24 * 60 * 60)).toBe(
      "1 week ago",
    );
  });

  it("returns '4 weeks ago' at 29 days", () => {
    expect(formatRelativeTime(now, now - 29 * 24 * 60 * 60)).toBe(
      "4 weeks ago",
    );
  });

  it("returns '1 month ago' at 30 days", () => {
    expect(formatRelativeTime(now, now - 30 * 24 * 60 * 60)).toBe(
      "1 month ago",
    );
  });
});

describe("maskPhoneTail", () => {
  it("formats a 4-char tail with bullet prefix", () => {
    expect(maskPhoneTail("4421")).toBe("••• 4421");
  });

  it("falls back when length is wrong", () => {
    expect(maskPhoneTail("12")).toBe("••• ----");
  });
});
