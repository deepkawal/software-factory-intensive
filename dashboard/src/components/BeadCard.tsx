import clsx from "clsx";
import type { Bead } from "@/api/types";
import { relativeTime } from "@/lib/time";

export function BeadCard({
  bead,
  stuck,
  onClick,
}: {
  bead: Bead;
  stuck?: boolean;
  onClick?: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={clsx(
        "group w-full rounded-md border bg-zinc-900/70 p-3 text-left transition hover:bg-zinc-800/80",
        stuck
          ? "border-rose-500/40 ring-1 ring-rose-500/20"
          : "border-zinc-800",
      )}
    >
      <div className="flex items-center justify-between gap-2">
        <span className="font-mono text-[10px] uppercase text-zinc-500">
          {bead.id}
        </span>
        {stuck ? (
          <span className="rounded bg-rose-500/15 px-1.5 py-0.5 text-[10px] text-rose-300">
            stuck
          </span>
        ) : null}
      </div>
      <p className="mt-1 line-clamp-3 text-sm text-zinc-200 group-hover:text-zinc-50">
        {bead.title || <em className="text-zinc-500">untitled</em>}
      </p>
      <div className="mt-2 flex flex-wrap items-center gap-2 text-[11px] text-zinc-400">
        {bead.assignee ? (
          <span className="rounded bg-zinc-800 px-1.5 py-0.5 font-mono">
            @{bead.assignee}
          </span>
        ) : null}
        {bead.issue_type && bead.issue_type !== "task" ? (
          <span className="rounded bg-zinc-800 px-1.5 py-0.5">
            {bead.issue_type}
          </span>
        ) : null}
        {bead.created_at ? <span>{relativeTime(bead.created_at)}</span> : null}
        {bead.dependencies?.length ? (
          <span
            title={bead.dependencies.map((d) => d.depends_on_id).join(", ")}
          >
            ← {bead.dependencies.length} dep
          </span>
        ) : null}
      </div>
    </button>
  );
}
