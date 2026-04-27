import { useMemo } from "react";
import { useAgents } from "@/api/hooks";
import { AgentTile } from "@/components/AgentTile";
import { SFI_AUX_ROLES, SFI_PIPELINE, matchRole } from "@/lib/pipeline";
import type { Agent } from "@/api/types";

export function AgentsPipeline({ city }: { city: string }) {
  const agents = useAgents(city);

  const byRole = useMemo(
    () => groupByRole(agents.data ?? []),
    [agents.data],
  );

  if (agents.isLoading) {
    return <p className="p-4 text-sm text-zinc-500">Loading agents…</p>;
  }
  if (agents.error) {
    return (
      <div className="rounded border border-rose-500/40 bg-rose-500/5 p-3 text-sm text-rose-200">
        Failed to load agents: {String(agents.error)}
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <section>
        <header className="mb-3 flex items-baseline justify-between">
          <h2 className="text-base font-semibold">Pipeline</h2>
          <span className="text-xs text-zinc-500">
            {agents.data?.length ?? 0} agents configured
          </span>
        </header>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-3 lg:grid-cols-6">
          {SFI_PIPELINE.map((r) => {
            const match = byRole[r.key] ?? [];
            return (
              <AgentTile
                key={r.key}
                role={r}
                agents={match}
                enabled={match.length > 0}
              />
            );
          })}
        </div>
      </section>

      <section>
        <header className="mb-3">
          <h3 className="text-sm font-semibold text-zinc-300">Auxiliary</h3>
        </header>
        <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-4">
          {SFI_AUX_ROLES.map((r) => {
            const match = byRole[r.key] ?? [];
            return (
              <AgentTile
                key={r.key}
                role={r}
                agents={match}
                enabled={match.length > 0}
              />
            );
          })}
        </div>
      </section>

      {byRole.__unmatched__?.length ? (
        <section>
          <h3 className="mb-2 text-sm font-semibold text-zinc-300">Other agents</h3>
          <ul className="grid grid-cols-1 gap-2 md:grid-cols-2 lg:grid-cols-3">
            {byRole.__unmatched__.map((a) => (
              <li
                key={a.name}
                className="rounded border border-zinc-800 bg-zinc-900/40 p-2 text-xs"
              >
                <p className="font-mono">{a.name}</p>
                <p className="text-zinc-500">
                  {a.running ? "running" : "stopped"}
                  {a.rig ? ` · ${a.rig}` : ""}
                </p>
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </div>
  );
}

function groupByRole(agents: Agent[]): Record<string, Agent[]> {
  const out: Record<string, Agent[]> = { __unmatched__: [] };
  for (const a of agents) {
    const key = matchRole(a.name, a.pool);
    if (!key) {
      out.__unmatched__.push(a);
      continue;
    }
    (out[key] ??= []).push(a);
  }
  return out;
}
