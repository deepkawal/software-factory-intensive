import clsx from "clsx";
import type { Agent } from "@/api/types";
import type { PipelineRole } from "@/lib/pipeline";
import { StatusDot, type DotTone } from "./StatusDot";
import { relativeTime } from "@/lib/time";

export function AgentTile({
  role,
  agents,
  enabled,
}: {
  role: PipelineRole;
  agents: Agent[];
  enabled: boolean;
}) {
  if (!enabled) {
    return (
      <div className="flex min-h-[136px] flex-col rounded-md border border-dashed border-zinc-800 bg-zinc-900/20 p-3 opacity-60">
        <h4 className="text-sm font-medium text-zinc-400">{role.title}</h4>
        <p className="mt-1 text-[11px] text-zinc-500">{role.blurb}</p>
        <p className="mt-auto text-[11px] italic text-zinc-600">
          not enabled in this activity
        </p>
      </div>
    );
  }

  const tone = pickTone(agents);
  const primary = agents[0];
  const last = primary?.session?.last_activity;

  return (
    <div className="flex min-h-[136px] flex-col rounded-md border border-zinc-800 bg-zinc-900/60 p-3 transition hover:border-zinc-700">
      <header className="flex items-center justify-between">
        <div>
          <h4 className="text-sm font-medium">{role.title}</h4>
          <p className="text-[11px] text-zinc-500">{role.blurb}</p>
        </div>
        <StatusDot tone={tone} />
      </header>

      <dl className="mt-2 space-y-1 text-[11px] text-zinc-300">
        <Stat label="instances" value={`${agents.length}`} />
        <Stat
          label="running"
          value={`${agents.filter((a) => a.running).length}`}
        />
        {primary?.active_bead ? (
          <Stat
            label="active"
            value={primary.active_bead}
            mono
            title={primary.active_bead}
          />
        ) : null}
        <Stat label="last" value={relativeTime(last)} />
      </dl>

      {primary?.last_output ? (
        <p
          className="mt-2 line-clamp-2 rounded bg-zinc-950/60 p-2 font-mono text-[10px] text-zinc-400"
          title={primary.last_output}
        >
          {primary.last_output}
        </p>
      ) : null}

      {primary?.context_pct != null ? (
        <ContextBar pct={primary.context_pct} model={primary.model} />
      ) : null}
    </div>
  );
}

function Stat({
  label,
  value,
  mono,
  title,
}: {
  label: string;
  value: string;
  mono?: boolean;
  title?: string;
}) {
  return (
    <div className="flex items-center justify-between gap-2">
      <dt className="text-zinc-500">{label}</dt>
      <dd
        title={title}
        className={clsx(
          "truncate text-zinc-200",
          mono && "font-mono text-[10px]",
        )}
      >
        {value}
      </dd>
    </div>
  );
}

function ContextBar({ pct, model }: { pct: number; model?: string }) {
  const tone =
    pct >= 90
      ? "bg-rose-500"
      : pct >= 75
        ? "bg-amber-500"
        : "bg-emerald-500";
  return (
    <div className="mt-2">
      <div className="flex justify-between text-[10px] text-zinc-500">
        <span>{model ?? "context"}</span>
        <span>{pct}%</span>
      </div>
      <div className="mt-1 h-1 w-full overflow-hidden rounded bg-zinc-800">
        <div className={clsx("h-full", tone)} style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}

function pickTone(agents: Agent[]): DotTone {
  if (!agents.length) return "off";
  if (agents.some((a) => a.suspended)) return "warn";
  const running = agents.filter((a) => a.running).length;
  if (running === 0) return "off";
  const idle = agents.every(
    (a) => a.activity === "idle" || a.activity === undefined,
  );
  if (idle) return "info";
  return "ok";
}
