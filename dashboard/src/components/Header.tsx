import type { ReactNode } from "react";
import clsx from "clsx";
import type { CityInfo, Rig } from "@/api/types";
import { StatusDot } from "./StatusDot";

type Tab = "beads" | "agents";

type HeaderProps = {
  cities: CityInfo[];
  loading: boolean;
  error: unknown;
  city: string | null;
  onCity: (c: string) => void;
  rigs: Rig[];
  rig: string | null;
  onRig: (r: string) => void;
  tab: Tab;
  onTab: (t: Tab) => void;
};

export function Header({
  cities,
  loading,
  error,
  city,
  onCity,
  rigs,
  rig,
  onRig,
  tab,
  onTab,
}: HeaderProps) {
  return (
    <header className="flex shrink-0 items-center gap-4 border-b border-zinc-800 bg-zinc-900/60 px-4 py-2.5 backdrop-blur">
      <div className="flex items-center gap-2">
        <span className="text-base font-semibold tracking-tight">SFI Factory</span>
        <span className="rounded bg-zinc-800 px-1.5 py-0.5 font-mono text-[10px] text-zinc-400">
          dashboard
        </span>
      </div>

      <div className="flex items-center gap-2">
        <label className="text-xs text-zinc-500">city</label>
        <select
          value={city ?? ""}
          onChange={(e) => onCity(e.target.value)}
          className="rounded border border-zinc-700 bg-zinc-900 px-2 py-1 text-sm focus:border-zinc-500 focus:outline-none"
        >
          <option value="" disabled>
            {loading ? "loading…" : "select city…"}
          </option>
          {cities.map((c) => (
            <option key={c.name} value={c.name}>
              {c.name}
              {c.running ? " ●" : " ○"}
            </option>
          ))}
        </select>
        {error ? (
          <span title={String(error)} className="flex items-center gap-1 text-xs text-rose-400">
            <StatusDot tone="bad" /> supervisor unreachable
          </span>
        ) : null}
      </div>

      {rigs.length > 0 ? (
        <div className="flex items-center gap-2">
          <label className="text-xs text-zinc-500">rig</label>
          <select
            value={rig ?? ""}
            onChange={(e) => onRig(e.target.value)}
            className="rounded border border-zinc-700 bg-zinc-900 px-2 py-1 text-sm focus:border-zinc-500 focus:outline-none"
          >
            {rigs.map((r) => (
              <option key={r.name} value={r.name}>
                {r.name}
                {r.suspended ? " (suspended)" : ""}
              </option>
            ))}
          </select>
        </div>
      ) : null}

      <nav className="ml-auto flex items-center gap-1 rounded-md bg-zinc-900 p-1 text-sm">
        <TabButton active={tab === "beads"} onClick={() => onTab("beads")}>
          Beads
        </TabButton>
        <TabButton active={tab === "agents"} onClick={() => onTab("agents")}>
          Agents
        </TabButton>
      </nav>
    </header>
  );
}

function TabButton({
  active,
  onClick,
  children,
}: {
  active: boolean;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      className={clsx(
        "rounded px-3 py-1 transition",
        active
          ? "bg-zinc-100 text-zinc-900"
          : "text-zinc-300 hover:bg-zinc-800",
      )}
    >
      {children}
    </button>
  );
}
