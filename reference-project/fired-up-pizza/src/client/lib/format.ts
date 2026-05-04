export function formatRating(avg: number | null): string {
  if (avg === null) {
    throw new Error("formatRating: caller must branch on null first");
  }
  return avg.toFixed(1);
}

export function formatReviewCount(count: number): string {
  return `(${count})`;
}

export function formatRelativeTime(now: number, then: number): string {
  const diff = Math.max(0, Math.floor(now - then));
  if (diff < 60) return "just now";

  const minutes = Math.floor(diff / 60);
  if (minutes < 60) {
    return minutes === 1 ? "1 minute ago" : `${minutes} minutes ago`;
  }

  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return hours === 1 ? "1 hour ago" : `${hours} hours ago`;
  }

  const days = Math.floor(hours / 24);
  if (days < 7) {
    return days === 1 ? "1 day ago" : `${days} days ago`;
  }

  if (days < 30) {
    const weeks = Math.floor(days / 7);
    return weeks === 1 ? "1 week ago" : `${weeks} weeks ago`;
  }

  const months = Math.floor(days / 30);
  return months === 1 ? "1 month ago" : `${months} months ago`;
}

export function maskPhoneTail(tail: string): string {
  if (tail.length !== 4) return "••• ----";
  return `••• ${tail}`;
}
