import type { ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "@/api/client";
import type { Bead } from "@/api/types";
import { relativeTime } from "@/lib/time";

export function BeadDrawer({
  city,
  beadId,
  onClose,
}: {
  city: string;
  beadId: string;
  onClose: () => void;
}) {
  const bead = useQuery({
    queryKey: ["bead", city, beadId],
    queryFn: () => api.getBead(city, beadId),
  });
  const deps = useQuery({
    queryKey: ["bead-deps", city, beadId],
    queryFn: () => api.beadDeps(city, beadId),
  });
  const eventsForBead = useQuery({
    queryKey: ["events-for-bead", city, beadId],
    queryFn: () => api.listEvents(city, { limit: 200 }),
    select: (rows) => rows.filter((e) => e.subject === beadId),
    refetchInterval: 5_000,
  });

  return (
    <div className="fixed inset-0 z-30 flex">
      <div
        className="flex-1 bg-black/60 backdrop-blur-sm"
        onClick={onClose}
        role="presentation"
      />
      <div className="flex h-full w-full max-w-xl flex-col overflow-hidden border-l border-zinc-800 bg-zinc-950 shadow-xl">
        <header className="flex items-center justify-between border-b border-zinc-800 px-4 py-3">
          <div>
            <p className="font-mono text-xs text-zinc-500">{beadId}</p>
            <h2 className="text-base font-semibold">
              {bead.data?.title ?? "Loading…"}
            </h2>
          </div>
          <button
            onClick={onClose}
            className="rounded px-2 py-1 text-sm text-zinc-400 hover:bg-zinc-800 hover:text-zinc-100"
          >
            close
          </button>
        </header>

        <div className="min-h-0 flex-1 overflow-auto p-4 text-sm">
          {bead.data ? <BeadDetails bead={bead.data} /> : null}

          <Section title="Dependencies">
            {deps.data?.children?.length ? (
              <ul className="space-y-1">
                {deps.data.children.map((c) => (
                  <li key={c.id} className="font-mono text-xs">
                    <span className="text-zinc-500">{c.id}</span> · {c.title}{" "}
                    <span className="text-zinc-500">({c.status})</span>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-xs text-zinc-500">No child beads.</p>
            )}
          </Section>

          <Section title="Recent events">
            {eventsForBead.data?.length ? (
              <ul className="space-y-1.5 font-mono text-[11px]">
                {eventsForBead.data.slice(0, 30).map((e) => (
                  <li key={e.seq} className="flex gap-2">
                    <span className="w-16 shrink-0 text-zinc-500">
                      {relativeTime(e.ts)}
                    </span>
                    <span className="text-zinc-300">{e.type}</span>
                    {e.actor ? (
                      <span className="text-zinc-500">@{e.actor}</span>
                    ) : null}
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-xs text-zinc-500">No events for this bead yet.</p>
            )}
          </Section>
        </div>
      </div>
    </div>
  );
}

function BeadDetails({ bead }: { bead: Bead }) {
  return (
    <dl className="grid grid-cols-3 gap-x-3 gap-y-2 text-xs">
      <Row label="status" value={bead.status} />
      <Row label="type" value={bead.issue_type} />
      <Row label="priority" value={bead.priority?.toString()} />
      <Row label="assignee" value={bead.assignee ?? "—"} />
      <Row label="created" value={relativeTime(bead.created_at)} />
      <Row
        label="labels"
        value={bead.labels?.length ? bead.labels.join(", ") : "—"}
        wide
      />
      {bead.description ? (
        <div className="col-span-3 mt-2">
          <span className="text-zinc-500">description</span>
          <pre className="mt-1 max-h-64 overflow-auto whitespace-pre-wrap rounded bg-zinc-900 p-3 text-xs text-zinc-200">
            {bead.description}
          </pre>
        </div>
      ) : null}
    </dl>
  );
}

function Row({
  label,
  value,
  wide,
}: {
  label: string;
  value?: string;
  wide?: boolean;
}) {
  return (
    <div className={wide ? "col-span-3" : ""}>
      <dt className="text-zinc-500">{label}</dt>
      <dd className="text-zinc-200">{value ?? "—"}</dd>
    </div>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <section className="mt-6">
      <h3 className="mb-2 text-xs font-semibold uppercase tracking-wide text-zinc-400">
        {title}
      </h3>
      {children}
    </section>
  );
}
