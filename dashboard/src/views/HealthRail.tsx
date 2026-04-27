import { useMemo, type ReactNode } from "react";
import { useAgents, useBeads, useCityStatus, useEvents, useOrders } from "@/api/hooks";
import { StatusDot, type DotTone } from "@/components/StatusDot";
import { formatUptime, relativeTime } from "@/lib/time";
import type { GcEvent } from "@/api/types";

const STUCK_THRESHOLD_MS = 10 * 60_000;
const HEARTBEAT_WARN_MS = 60_000;
const HEARTBEAT_BAD_MS = 5 * 60_000;

export function HealthRail({
  city,
  rig,
}: {
  city: string;
  rig: string | null;
}) {
  const status = useCityStatus(city);
  const agents = useAgents(city);
  const beads = useBeads(city, rig);
  const events = useEvents(city);
  const orders = useOrders(city);

  const heartbeat = useMemo(() => heartbeatTone(events.data ?? []), [events.data]);
  const stuck = useMemo(
    () => countStuck(beads.data ?? [], events.data ?? []),
    [beads.data, events.data],
  );
  const recentFailures = useMemo(
    () =>
      (events.data ?? []).filter(
        (e) =>
          e.type === "session.crashed" ||
          e.type === "order.failed" ||
          e.type === "session.idle_killed",
      ),
    [events.data],
  );

  const overall = computeOverall({
    suspended: status.data?.suspended ?? false,
    heartbeat: heartbeat.tone,
    stuck,
    failures: recentFailures.length,
    error: status.error,
  });

  return (
    <div className="space-y-4 text-sm">
      <Card>
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-semibold">Health</h3>
          <StatusDot tone={overall.tone} pulse={overall.tone !== "ok"} />
        </div>
        <p className="mt-1 text-xs text-zinc-400">{overall.headline}</p>
      </Card>

      <Card>
        <Row label="Controller">
          {status.error ? (
            <Bad>unreachable</Bad>
          ) : status.data?.suspended ? (
            <Warn>suspended</Warn>
          ) : (
            <Ok>up</Ok>
          )}
        </Row>
        <Row label="Uptime">
          <span className="text-zinc-300">
            {status.data ? formatUptime(status.data.uptime_sec) : "—"}
          </span>
        </Row>
        <Row label="Version">
          <span className="font-mono text-xs text-zinc-400">
            {status.data?.version ?? "—"}
          </span>
        </Row>
        <Row label="Event heartbeat">
          <span className={heartbeat.className}>{heartbeat.label}</span>
        </Row>
      </Card>

      <Card title="At a glance">
        <Row label="Agents running">
          <span>
            {status.data?.agents.running ?? "—"}
            <span className="text-zinc-500">
              /{status.data?.agents.total ?? "—"}
            </span>
          </span>
        </Row>
        <Row label="Rigs">
          <span>{status.data?.rigs.total ?? "—"}</span>
        </Row>
        <Row label="Open work">
          <span>{status.data?.work.open ?? "—"}</span>
        </Row>
        <Row label="In progress">
          <span>{status.data?.work.in_progress ?? "—"}</span>
        </Row>
        <Row label="Suspended agents">
          <span>{status.data?.agents.suspended ?? "—"}</span>
        </Row>
      </Card>

      <Card title={`Stuck beads (${stuck.count})`}>
        {stuck.count === 0 ? (
          <p className="text-xs text-zinc-500">Nothing has been waiting more than 10 minutes.</p>
        ) : (
          <ul className="space-y-1 text-xs">
            {stuck.examples.map((e) => (
              <li key={e.id} className="flex justify-between gap-2">
                <span className="font-mono text-zinc-400">{e.id}</span>
                <span className="truncate text-zinc-500" title={e.title}>
                  {e.title || "untitled"}
                </span>
              </li>
            ))}
            {stuck.count > stuck.examples.length ? (
              <li className="text-[11px] text-zinc-500">
                +{stuck.count - stuck.examples.length} more
              </li>
            ) : null}
          </ul>
        )}
      </Card>

      <Card title="Intake gates">
        {orders.data?.length ? (
          <ul className="space-y-1 text-xs">
            {orders.data.slice(0, 8).map((o) => (
              <li key={o.name} className="flex items-center justify-between gap-2">
                <span className="truncate font-mono text-zinc-300">{o.name}</span>
                <span className="text-zinc-500">
                  {o.pool ? `→ ${o.pool}` : o.gate ?? "—"}
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-xs text-zinc-500">No orders configured.</p>
        )}
      </Card>

      <Card title={`Recent failures (${recentFailures.length})`}>
        {recentFailures.length === 0 ? (
          <p className="text-xs text-zinc-500">Clean — no crashes or failures recently.</p>
        ) : (
          <ul className="space-y-1 text-xs">
            {recentFailures.slice(0, 5).map((e) => (
              <li key={e.seq} className="flex justify-between gap-2">
                <span className="text-zinc-300">{e.type}</span>
                <span className="text-zinc-500">{relativeTime(e.ts)}</span>
              </li>
            ))}
          </ul>
        )}
      </Card>

      <p className="text-[11px] text-zinc-600">
        Polling once per cycle.{" "}
        {agents.dataUpdatedAt
          ? `Agents refreshed ${relativeTime(new Date(agents.dataUpdatedAt).toISOString())}.`
          : ""}
      </p>
    </div>
  );
}

function Card({
  title,
  children,
}: {
  title?: string;
  children: ReactNode;
}) {
  return (
    <section className="rounded-md border border-zinc-800 bg-zinc-900/40 p-3">
      {title ? (
        <h4 className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-zinc-400">
          {title}
        </h4>
      ) : null}
      <div className="space-y-1">{children}</div>
    </section>
  );
}

function Row({
  label,
  children,
}: {
  label: string;
  children: ReactNode;
}) {
  return (
    <div className="flex items-center justify-between gap-2 text-xs">
      <span className="text-zinc-500">{label}</span>
      {children}
    </div>
  );
}

const Ok = ({ children }: { children: ReactNode }) => (
  <span className="text-emerald-300">{children}</span>
);
const Warn = ({ children }: { children: ReactNode }) => (
  <span className="text-amber-300">{children}</span>
);
const Bad = ({ children }: { children: ReactNode }) => (
  <span className="text-rose-300">{children}</span>
);

function heartbeatTone(events: GcEvent[]): {
  tone: DotTone;
  label: string;
  className: string;
} {
  if (!events.length) {
    return { tone: "warn", label: "no events yet", className: "text-amber-300" };
  }
  const latest = events.reduce((acc, e) =>
    new Date(e.ts).getTime() > new Date(acc.ts).getTime() ? e : acc,
  );
  const age = Date.now() - new Date(latest.ts).getTime();
  if (age > HEARTBEAT_BAD_MS)
    return {
      tone: "bad",
      label: relativeTime(latest.ts),
      className: "text-rose-300",
    };
  if (age > HEARTBEAT_WARN_MS)
    return {
      tone: "warn",
      label: relativeTime(latest.ts),
      className: "text-amber-300",
    };
  return {
    tone: "ok",
    label: relativeTime(latest.ts),
    className: "text-emerald-300",
  };
}

function countStuck(
  beads: {
    id: string;
    title: string;
    assignee?: string;
    status: string;
    issue_type: string;
  }[],
  events: GcEvent[],
): { count: number; examples: { id: string; title: string }[] } {
  const lastBy: Record<string, number> = {};
  for (const e of events) {
    if (!e.subject) continue;
    const t = new Date(e.ts).getTime();
    if (!lastBy[e.subject] || t > lastBy[e.subject]) lastBy[e.subject] = t;
  }
  const seen = new Set<string>();
  const stuck = [];
  for (const b of beads) {
    if (seen.has(b.id)) continue;
    seen.add(b.id);
    if (b.issue_type !== "task") continue;
    if (!b.assignee || b.status === "closed") continue;
    const last = lastBy[b.id] ?? 0;
    if (Date.now() - last > STUCK_THRESHOLD_MS) stuck.push(b);
  }
  return {
    count: stuck.length,
    examples: stuck.slice(0, 6).map((b) => ({ id: b.id, title: b.title })),
  };
}

function computeOverall(s: {
  suspended: boolean;
  heartbeat: DotTone;
  stuck: { count: number };
  failures: number;
  error: unknown;
}): { tone: DotTone; headline: string } {
  if (s.error) return { tone: "bad", headline: "Supervisor unreachable." };
  if (s.suspended) return { tone: "warn", headline: "City is suspended." };
  if (s.heartbeat === "bad")
    return { tone: "bad", headline: "Event bus has gone silent." };
  if (s.failures > 0)
    return {
      tone: "warn",
      headline: `${s.failures} recent failures — check below.`,
    };
  if (s.stuck.count > 0)
    return {
      tone: "warn",
      headline: `${s.stuck.count} bead(s) waiting > 10 min.`,
    };
  if (s.heartbeat === "warn")
    return { tone: "warn", headline: "Event stream is quiet." };
  return { tone: "ok", headline: "Factory looks healthy." };
}
