export type NormalizePhoneResult =
  | { ok: true; value: string }
  | { ok: false };

export function normalizePhone(input: unknown): NormalizePhoneResult {
  if (typeof input !== "string") return { ok: false };
  const trimmed = input.trim();
  if (trimmed.length === 0) return { ok: false };

  const digits = trimmed.replace(/[^\d]/g, "");
  if (digits.length < 7 || digits.length > 15) return { ok: false };

  if (trimmed.startsWith("+")) {
    return { ok: true, value: `+${digits}` };
  }

  if (digits.length === 10) {
    return { ok: true, value: `+1${digits}` };
  }

  if (digits.length === 11 && digits.startsWith("1")) {
    return { ok: true, value: `+${digits}` };
  }

  return { ok: true, value: `+${digits}` };
}
