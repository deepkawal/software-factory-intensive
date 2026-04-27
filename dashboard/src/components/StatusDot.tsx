import clsx from "clsx";

export type DotTone = "ok" | "warn" | "bad" | "off" | "info";

const TONE: Record<DotTone, string> = {
  ok: "bg-emerald-500 shadow-emerald-500/50",
  warn: "bg-amber-500 shadow-amber-500/50",
  bad: "bg-rose-500 shadow-rose-500/50",
  off: "bg-zinc-500 shadow-zinc-500/30",
  info: "bg-sky-500 shadow-sky-500/50",
};

export function StatusDot({
  tone,
  pulse,
  className,
}: {
  tone: DotTone;
  pulse?: boolean;
  className?: string;
}) {
  return (
    <span
      className={clsx(
        "inline-block size-2.5 rounded-full shadow-[0_0_6px_currentColor]",
        TONE[tone],
        pulse && "animate-pulse",
        className,
      )}
    />
  );
}
