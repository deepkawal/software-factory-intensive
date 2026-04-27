# SFI Factory Dashboard

A read-only web dashboard for visualizing the live state of factories built
during the Software Factory Intensive curriculum. It speaks the SFI
vocabulary — labeled beads, the six pipeline roles, intake gates — and reads
everything from the Gas City supervisor HTTP API. No backend of its own.

## What it shows

Three answers, on one screen:

1. **State of all beads** — Kanban grouped by the SFI label flow
   (`needs-plan` → `needs-architecture` → `needs-design` → `ready-to-build`
   → `needs-review` → `ready-to-ship`), with a stuck-bead filter and a
   bead-detail drawer.
2. **State of agents** — pipeline strip with one tile per role
   (Planner, Architect, Designer, Coder, Reviewer, Deployer; plus
   Supervisor / Improver / Validator / PM auxiliaries). Each tile shows
   liveness, instance count, current bead, last-output tail, and context
   usage. Roles not enabled in the current activity render greyed out.
3. **Whether the factory is running properly** — a Health rail with
   controller status, event-bus heartbeat, suspended-agent count,
   stuck-bead count with examples, intake-gate listing, and recent
   failures.

A collapsible **event drawer** at the bottom polls the supervisor's event
log and shows a live, color-coded tail.

## Prerequisites

- Node.js 20+ and a package manager (`npm`, `pnpm`, or `bun`).
- A Gas City supervisor reachable over HTTP. Locally that's `gc start` in
  a registered factory directory; the supervisor binds to
  `http://127.0.0.1:8372` by default.
- At least one running city. Multiple is fine — supervisor mode multiplexes
  them and the dashboard exposes a city dropdown.

## Run

```bash
cd software-factory-intensive/dashboard
npm install
npm run dev
```

Open `http://localhost:5273`.

To point at a non-default supervisor:

```bash
cp .env.example .env
# edit VITE_GC_API_URL
```

## Build

```bash
npm run build
npm run preview
```

`dist/` is a static bundle and can be served by any static host (or
`go:embed`-ed into a future `sfi-dash` binary).

## Architecture

```
src/
  api/
    client.ts       # typed wrapper over /v0 API + supervisor city scoping
    hooks.ts        # React Query hooks (polling intervals per resource)
    types.ts        # response shapes
  lib/
    labels.ts       # SFI label flow constants
    pipeline.ts     # SFI pipeline role definitions + matching
    time.ts         # relative-time formatting
  components/
    Header.tsx      # title, city selector, tab nav
    StatusDot.tsx
    BeadCard.tsx
    BeadDrawer.tsx  # bead detail + deps + event timeline
    AgentTile.tsx
    EventDrawer.tsx # bottom event tail
  views/
    BeadBoard.tsx
    AgentsPipeline.tsx
    HealthRail.tsx
```

### Data flow

All data comes from the supervisor at `VITE_GC_API_URL` (default
`http://localhost:8372`).

| Resource | Endpoint | Refresh |
|---|---|---|
| Cities | `GET /v0/cities` | 15s |
| City status | `GET /v0/city/{name}/status` | 5s |
| Agents | `GET /v0/city/{name}/agents` | 5s |
| Beads | `GET /v0/city/{name}/beads` | 5s |
| Bead detail | `GET /v0/city/{name}/bead/{id}` | on demand |
| Bead deps | `GET /v0/city/{name}/bead/{id}/deps` | on demand |
| Events | `GET /v0/city/{name}/events` | 4s (and 2.5s for the drawer) |
| Orders | `GET /v0/city/{name}/orders` | 15s |

Events are polled with seq-deduped merging into a 500-event ring buffer.
Polling was chosen over SSE because the supervisor's `/v0/events/stream`
emits typed `event:` lines that don't fan out through `EventSource.onmessage`,
and the polling pattern keeps the front end simple.

### Why supervisor mode by default

Workshop participants typically have several factories registered at once
(W1 + L1 in the same week, etc.). Pointing at the supervisor lets the
dashboard list every city and switch between them. The dashboard also
works when only one city is registered — it auto-selects it.

## Read-only today; the seam for actions

Every mutation route the API exposes (`POST /v0/sling`,
`POST /v0/order/{name}/enable`, `POST /v0/session/{id}/messages`,
`POST /v0/bead/{id}/close`, etc.) is intentionally not wired up. When we
add write actions (e.g. "send a message to this agent's session"), they
go in `src/api/client.ts` next to their read peers, gated by a flag the
header surfaces. Bead and Agent drawers are the natural homes for those
buttons.

## Known gaps

- `gc doctor` doesn't have a JSON output mode yet, so the Health rail
  derives its overall verdict from controller status + event heartbeat +
  stuck count + recent failures. A `gc doctor --json` would let us
  surface the actual check list verbatim.
- The order list endpoint exists but the response shape (`gate`,
  `schedule`, `last_fired`, `last_result`) is best-effort in the types
  here — if the API expands, update `src/api/types.ts:Order`.
- Pack customization diff (which packs the participant has overridden in
  `activities/<slug>/packs/`) is intentionally out of scope for v1.
