import { useEffect, useMemo, useState } from "react";
import clsx from "clsx";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/api/client";
import type { GcEvent } from "@/api/types";
import { relativeTime } from "@/lib/time";

const MAX_BUFFER = 500;
const POLL_MS = 2_500;

const TYPE_TONE: Record<string, string> = {
  "bead.created": "text-sky-300",
  "bead.updated": "text-sky-200",
  "bead.closed": "text-emerald-300",
  "session.woke": "text-emerald-300",
  "session.stopped": "text-zinc-400",
  "session.crashed": "text-rose-300",
  "session.idle_killed": "text-amber-300",
  "order.fired": "text-fuchsia-300",
  "order.completed": "text-emerald-300",
  "order.failed": "text-rose-300",
};

export function EventDrawer({ city }: { city: string | null }) {
  const [open, setOpen] = useState(true);
  const [buffer, setBuffer] = useState<GcEvent[]>([]);
  const [filter, setFilter] = useState("");

  const poll = useQuery({
    queryKey: ["event-drawer", city],
    queryFn: () => api.listEvents(city, { limit: 200 }),
    enabled: city !== null,
    refetchInterval: POLL_MS,
  });

  useEffect(() => {
    setBuffer([]);
  }, [city]);

  useEffect(() => {
    if (!poll.data) return;
    setBuffer((prev) => mergeBySeq(prev, poll.data));
  }, [poll.data]);

  const filtered = useMemo(() => {
    if (!filter) return buffer;
    const f = filter.toLowerCase();
    return buffer.filter(
      (e) =>
        e.type.toLowerCase().includes(f) ||
        (e.actor ?? "").toLowerCase().includes(f) ||
        (e.subject ?? "").toLowerCase().includes(f),
    );
  }, [buffer, filter]);

  const live = !!city && !poll.error && poll.dataUpdatedAt > 0;

  return (
    <section
      className={clsx(
        "border-t border-zinc-800 bg-zinc-950 transition-all",
        open ? "h-64" : "h-9",
      )}
    >
      <header className="flex h-9 shrink-0 items-center gap-3 border-b border-zinc-900 px-3 text-xs">
        <button
          className="rounded px-2 py-0.5 text-zinc-300 hover:bg-zinc-800"
          onClick={() => setOpen((v) => !v)}
        >
          {open ? "▾" : "▸"} events
        </button>
        <span
          className={clsx(
            "font-mono",
            live ? "text-emerald-400" : "text-zinc-500",
          )}
        >
          {live ? "● live" : "○ idle"}
        </span>
        {open ? (
          <input
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            placeholder="filter type / actor / subject"
            className="ml-2 w-72 rounded border border-zinc-800 bg-zinc-900 px-2 py-0.5 text-xs focus:border-zinc-600 focus:outline-none"
          />
        ) : null}
        <span className="ml-auto text-zinc-500">
          {filtered.length}/{buffer.length}
        </span>
      </header>

      {open ? (
        <ul className="h-[calc(100%-2.25rem)] divide-y divide-zinc-900 overflow-auto font-mono text-[11px]">
          {filtered.map((e) => (
            <li key={e.seq} className="flex gap-3 px-3 py-1">
              <span className="w-16 shrink-0 text-zinc-500">
                {relativeTime(e.ts)}
              </span>
              <span
                className={clsx(
                  "w-44 shrink-0",
                  TYPE_TONE[e.type] ?? "text-zinc-300",
                )}
              >
                {e.type}
              </span>
              {e.actor ? (
                <span className="w-32 shrink-0 truncate text-zinc-400">
                  @{e.actor}
                </span>
              ) : (
                <span className="w-32 shrink-0" />
              )}
              {e.subject ? (
                <span className="w-32 shrink-0 truncate text-zinc-500">
                  {e.subject}
                </span>
              ) : null}
              <span className="truncate text-zinc-300">{e.message}</span>
            </li>
          ))}
          {filtered.length === 0 ? (
            <li className="px-3 py-2 text-zinc-600">No events yet.</li>
          ) : null}
        </ul>
      ) : null}
    </section>
  );
}

function mergeBySeq(prev: GcEvent[], incoming: GcEvent[]): GcEvent[] {
  if (!incoming.length) return prev;
  const bySeq = new Map<number, GcEvent>();
  for (const e of prev) bySeq.set(e.seq, e);
  for (const e of incoming) bySeq.set(e.seq, e);
  return Array.from(bySeq.values())
    .sort((a, b) => b.seq - a.seq)
    .slice(0, MAX_BUFFER);
}
