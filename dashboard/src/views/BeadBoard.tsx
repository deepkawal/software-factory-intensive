import { useMemo, useState, type ReactNode } from "react";
import clsx from "clsx";
import { useBeads, useEvents } from "@/api/hooks";
import {
  ALL_SFI_LABELS,
  SFI_AUX_LABELS,
  SFI_LABELS,
  pickPrimaryLabel,
} from "@/lib/labels";
import { BeadCard } from "@/components/BeadCard";
import type { Bead, GcEvent } from "@/api/types";

const STUCK_THRESHOLD_MS = 10 * 60_000;
const NON_WORK_TYPES = new Set([
  "convoy",
  "message",
  "convergence",
  "session",
  "wisp",
  "molecule",
]);

export function BeadBoard({
  city,
  rig,
  onOpenBead,
}: {
  city: string;
  rig: string | null;
  onOpenBead: (id: string) => void;
}) {
  const beads = useBeads(city, rig);
  const events = useEvents(city);
  const [stuckOnly, setStuckOnly] = useState(false);
  const [showNonWork, setShowNonWork] = useState(false);
  const [showAux, setShowAux] = useState(false);

  const lastEventBySubject = useMemo(
    () => indexEventsBySubject(events.data ?? []),
    [events.data],
  );

  const grouped = useMemo(() => {
    const map: Record<string, Bead[]> = Object.fromEntries(
      ALL_SFI_LABELS.map((l) => [l.key, [] as Bead[]]),
    );
    map["__other__"] = [];
    map["__closed__"] = [];
    const seen = new Set<string>();
    for (const b of beads.data ?? []) {
      if (seen.has(b.id)) continue;
      seen.add(b.id);
      if (!showNonWork && NON_WORK_TYPES.has(b.issue_type)) continue;
      if (b.status === "closed") {
        map["__closed__"].push(b);
        continue;
      }
      const label = pickPrimaryLabel(b.labels);
      if (label) map[label].push(b);
      else map["__other__"].push(b);
    }
    return map;
  }, [beads.data, showNonWork]);

  const isStuck = (b: Bead) => {
    if (!b.assignee || b.status === "closed") return false;
    const last = lastEventBySubject[b.id];
    const ts = last ? new Date(last.ts).getTime() : 0;
    return Date.now() - ts > STUCK_THRESHOLD_MS;
  };

  const totalStuck = (beads.data ?? []).filter(isStuck).length;

  if (beads.isLoading) return <Loading />;
  if (beads.error) return <ErrorBox error={beads.error} />;

  return (
    <div className="flex h-full min-h-0 flex-col gap-4">
      <Toolbar
        total={(beads.data ?? []).filter(
          (b) => showNonWork || !NON_WORK_TYPES.has(b.issue_type),
        ).length}
        stuck={totalStuck}
        stuckOnly={stuckOnly}
        onStuckOnly={setStuckOnly}
        showNonWork={showNonWork}
        onShowNonWork={setShowNonWork}
        showAux={showAux}
        onShowAux={setShowAux}
        auxBadgeCount={SFI_AUX_LABELS.reduce(
          (acc, l) =>
            acc +
            (
              (grouped[l.key] ?? []).filter((b) => !stuckOnly || isStuck(b))
            ).length,
          0,
        )}
        rig={rig}
      />

      <div className="grid min-h-0 flex-1 auto-cols-[minmax(200px,1fr)] grid-flow-col gap-3 overflow-x-auto pb-2">
        {(showAux ? ALL_SFI_LABELS : SFI_LABELS).map((l) => {
          const cards = (grouped[l.key] ?? []).filter(
            (b) => !stuckOnly || isStuck(b),
          );
          return (
            <Column
              key={l.key}
              title={l.title}
              hint={l.description}
              accent={l.accent}
              count={cards.length}
            >
              {cards.map((b) => (
                <BeadCard
                  key={b.id}
                  bead={b}
                  stuck={isStuck(b)}
                  onClick={() => onOpenBead(b.id)}
                />
              ))}
            </Column>
          );
        })}
        <Column
          title="Other"
          hint="Unlabeled / non-pipeline"
          accent="bg-zinc-700/30 text-zinc-300 border-zinc-600/40"
          count={(grouped["__other__"] ?? []).filter(
            (b) => !stuckOnly || isStuck(b),
          ).length}
        >
          {(grouped["__other__"] ?? [])
            .filter((b) => !stuckOnly || isStuck(b))
            .map((b) => (
              <BeadCard
                key={b.id}
                bead={b}
                stuck={isStuck(b)}
                onClick={() => onOpenBead(b.id)}
              />
            ))}
        </Column>
      </div>
    </div>
  );
}

function Column({
  title,
  hint,
  accent,
  count,
  children,
}: {
  title: string;
  hint: string;
  accent: string;
  count: number;
  children: ReactNode;
}) {
  return (
    <div className="flex min-w-0 flex-col rounded-md border border-zinc-800 bg-zinc-900/30">
      <header className="flex items-center justify-between gap-2 border-b border-zinc-800 px-2.5 py-2">
        <div className="min-w-0">
          <h3 className="truncate text-sm font-medium">{title}</h3>
          <p className="truncate text-[11px] text-zinc-500">{hint}</p>
        </div>
        <span
          className={clsx(
            "rounded border px-1.5 py-0.5 text-[11px] font-medium",
            accent,
          )}
        >
          {count}
        </span>
      </header>
      <div className="min-h-0 flex-1 space-y-2 overflow-auto p-2">
        {children}
      </div>
    </div>
  );
}

function Toolbar({
  total,
  stuck,
  stuckOnly,
  onStuckOnly,
  showNonWork,
  onShowNonWork,
  showAux,
  onShowAux,
  auxBadgeCount,
  rig,
}: {
  total: number;
  stuck: number;
  stuckOnly: boolean;
  onStuckOnly: (v: boolean) => void;
  showNonWork: boolean;
  onShowNonWork: (v: boolean) => void;
  showAux: boolean;
  onShowAux: (v: boolean) => void;
  auxBadgeCount: number;
  rig: string | null;
}) {
  return (
    <div className="flex items-center gap-3 text-sm">
      <h2 className="text-base font-semibold">Beads</h2>
      <span className="text-zinc-500">
        {total} {rig ? `in ${rig}` : "across all rigs"}
      </span>
      {stuck > 0 ? (
        <button
          onClick={() => onStuckOnly(!stuckOnly)}
          className={clsx(
            "rounded border px-2 py-1 text-xs",
            stuckOnly
              ? "border-rose-500/60 bg-rose-500/10 text-rose-300"
              : "border-zinc-700 text-zinc-300 hover:border-rose-500/40",
          )}
        >
          {stuck} stuck {stuckOnly ? "(showing)" : "— filter"}
        </button>
      ) : null}
      <button
        onClick={() => onShowAux(!showAux)}
        className={clsx(
          "ml-auto rounded border px-2 py-1 text-xs",
          showAux
            ? "border-zinc-500 bg-zinc-800 text-zinc-100"
            : "border-zinc-700 text-zinc-300 hover:border-zinc-500",
        )}
      >
        {showAux ? "hide aux" : "show aux lanes"}
        {auxBadgeCount > 0 && !showAux ? (
          <span className="ml-1.5 rounded bg-zinc-700 px-1 text-[10px]">
            {auxBadgeCount}
          </span>
        ) : null}
      </button>
      <label className="flex items-center gap-1.5 text-xs text-zinc-400">
        <input
          type="checkbox"
          checked={showNonWork}
          onChange={(e) => onShowNonWork(e.target.checked)}
        />
        show convoys / sessions
      </label>
    </div>
  );
}

function Loading() {
  return (
    <p className="p-4 text-sm text-zinc-500">Loading beads…</p>
  );
}

function ErrorBox({ error }: { error: unknown }) {
  return (
    <div className="rounded border border-rose-500/40 bg-rose-500/5 p-3 text-sm text-rose-200">
      Failed to load beads: {String(error)}
    </div>
  );
}

function indexEventsBySubject(events: GcEvent[]): Record<string, GcEvent> {
  const map: Record<string, GcEvent> = {};
  for (const e of events) {
    if (!e.subject) continue;
    const prev = map[e.subject];
    if (!prev || new Date(e.ts).getTime() > new Date(prev.ts).getTime()) {
      map[e.subject] = e;
    }
  }
  return map;
}
