import { useEffect, useState } from "react";
import { Header } from "@/components/Header";
import { EventDrawer } from "@/components/EventDrawer";
import { BeadDrawer } from "@/components/BeadDrawer";
import { HealthRail } from "@/views/HealthRail";
import { BeadBoard } from "@/views/BeadBoard";
import { AgentsPipeline } from "@/views/AgentsPipeline";
import { useCities, useRigs } from "@/api/hooks";

type Tab = "beads" | "agents";

export function App() {
  const [tab, setTab] = useState<Tab>("beads");
  const [city, setCity] = useState<string | null>(null);
  const [rig, setRig] = useState<string | null>(null);
  const [openBead, setOpenBead] = useState<string | null>(null);
  const cities = useCities();
  const rigs = useRigs(city);

  useEffect(() => {
    if (city || !cities.data?.length) return;
    const running = cities.data.filter((c) => c.running);
    if (running.length >= 1) setCity(running[0].name);
    else setCity(cities.data[0].name);
  }, [city, cities.data]);

  useEffect(() => {
    setRig(null);
  }, [city]);

  useEffect(() => {
    if (rig || !rigs.data?.length) return;
    setRig(rigs.data[0].name);
  }, [rig, rigs.data]);

  return (
    <div className="flex h-full flex-col">
      <Header
        cities={cities.data ?? []}
        loading={cities.isLoading}
        error={cities.error}
        city={city}
        onCity={setCity}
        rigs={rigs.data ?? []}
        rig={rig}
        onRig={setRig}
        tab={tab}
        onTab={setTab}
      />

      <main className="flex min-h-0 flex-1 overflow-hidden">
        <section className="min-h-0 flex-1 overflow-auto p-4">
          {!city ? (
            <EmptyCity hasCities={(cities.data?.length ?? 0) > 0} />
          ) : tab === "beads" ? (
            <BeadBoard city={city} rig={rig} onOpenBead={setOpenBead} />
          ) : (
            <AgentsPipeline city={city} />
          )}
        </section>
        <aside className="hidden w-80 shrink-0 overflow-auto border-l border-zinc-800 bg-zinc-950/40 p-4 lg:block">
          {city ? (
            <HealthRail city={city} rig={rig} />
          ) : (
            <p className="text-sm text-zinc-500">Select a city to see health.</p>
          )}
        </aside>
      </main>

      <EventDrawer city={city} />

      {openBead && city && (
        <BeadDrawer
          city={city}
          beadId={openBead}
          onClose={() => setOpenBead(null)}
        />
      )}
    </div>
  );
}

function EmptyCity({ hasCities }: { hasCities: boolean }) {
  return (
    <div className="grid h-full place-items-center text-center">
      <div className="max-w-md space-y-2">
        <h2 className="text-lg font-semibold">No city selected</h2>
        <p className="text-sm text-zinc-400">
          {hasCities
            ? "Pick a city from the dropdown above."
            : "No cities are registered with the supervisor. Run gc start in a factory directory."}
        </p>
      </div>
    </div>
  );
}
