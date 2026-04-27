import type {
  Agent,
  Bead,
  CityInfo,
  CityStatus,
  GcEvent,
  ListResponse,
  Order,
  Rig,
} from "./types";

const BASE_URL =
  (import.meta.env.VITE_GC_API_URL as string | undefined)?.replace(/\/$/, "") ||
  "http://localhost:8372";

class ApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly code?: string,
  ) {
    super(message);
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    ...init,
    headers: { Accept: "application/json", ...(init?.headers || {}) },
  });
  if (!res.ok) {
    let code: string | undefined;
    let msg = `${res.status} ${res.statusText}`;
    try {
      const body = await res.json();
      code = body.code;
      if (body.message) msg = body.message;
    } catch {
      // body wasn't JSON
    }
    throw new ApiError(msg, res.status, code);
  }
  return res.json() as Promise<T>;
}

const cityScope = (city: string | null) =>
  city ? `/v0/city/${encodeURIComponent(city)}` : "/v0";

export const api = {
  baseUrl: BASE_URL,

  listCities: () =>
    request<ListResponse<CityInfo> | { items?: CityInfo[] } | CityInfo[]>(
      "/v0/cities",
    ).then(normalizeList<CityInfo>),

  cityStatus: (city: string | null) =>
    request<CityStatus>(`${cityScope(city)}/status`),

  listAgents: (city: string | null, opts?: { rig?: string; pool?: string }) => {
    const qs = new URLSearchParams();
    if (opts?.rig) qs.set("rig", opts.rig);
    if (opts?.pool) qs.set("pool", opts.pool);
    const tail = qs.toString() ? `?${qs}` : "";
    return request<ListResponse<Agent>>(
      `${cityScope(city)}/agents${tail}`,
    ).then((r) => r.items);
  },

  listRigs: (city: string | null) =>
    request<ListResponse<Rig>>(`${cityScope(city)}/rigs`).then((r) => r.items),

  listBeads: (
    city: string | null,
    opts?: { rig?: string; status?: string; label?: string; assignee?: string; limit?: number },
  ) => {
    const qs = new URLSearchParams();
    if (opts?.rig) qs.set("rig", opts.rig);
    if (opts?.status) qs.set("status", opts.status);
    if (opts?.label) qs.set("label", opts.label);
    if (opts?.assignee) qs.set("assignee", opts.assignee);
    if (opts?.limit) qs.set("limit", String(opts.limit));
    const tail = qs.toString() ? `?${qs}` : "";
    return request<ListResponse<Bead>>(`${cityScope(city)}/beads${tail}`).then(
      (r) => r.items,
    );
  },

  getBead: (city: string | null, id: string) =>
    request<Bead>(`${cityScope(city)}/bead/${encodeURIComponent(id)}`),

  beadDeps: (city: string | null, id: string) =>
    request<{ children: Bead[] }>(
      `${cityScope(city)}/bead/${encodeURIComponent(id)}/deps`,
    ),

  listEvents: (
    city: string | null,
    opts?: { type?: string; since?: string; limit?: number },
  ) => {
    const qs = new URLSearchParams();
    if (opts?.type) qs.set("type", opts.type);
    if (opts?.since) qs.set("since", opts.since);
    if (opts?.limit) qs.set("limit", String(opts.limit));
    const tail = qs.toString() ? `?${qs}` : "";
    const root = city ? `${cityScope(city)}/events` : "/v0/events";
    return request<ListResponse<GcEvent>>(`${root}${tail}`).then((r) => r.items);
  },

  listOrders: (city: string | null) =>
    request<{ orders?: Order[] }>(`${cityScope(city)}/orders`).then(
      (r) => r.orders ?? [],
    ),

  agentTranscriptUrl: (city: string | null, name: string) =>
    `${BASE_URL}${cityScope(city)}/agent/${encodeURIComponent(name)}/output`,
};

function normalizeList<T>(
  raw: ListResponse<T> | { items?: T[] } | T[],
): T[] {
  if (Array.isArray(raw)) return raw;
  if ("items" in raw && Array.isArray(raw.items)) return raw.items;
  return [];
}

export { ApiError };
