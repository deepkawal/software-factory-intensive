export type ListResponse<T> = {
  items: T[];
  total: number;
  next_cursor?: string;
};

export type CityInfo = {
  name: string;
  path: string;
  running: boolean;
  status?: string;
  error?: string;
  phases_completed?: string[];
};

export type CityStatus = {
  name: string;
  path: string;
  version?: string;
  uptime_sec: number;
  suspended: boolean;
  agent_count: number;
  rig_count: number;
  running: number;
  agents: {
    total: number;
    running: number;
    suspended: number;
    quarantined: number;
  };
  rigs: { total: number; suspended: number };
  work: { in_progress: number; ready: number; open: number };
  mail: { unread: number; total: number };
};

export type SessionInfo = {
  name: string;
  last_activity?: string;
  attached: boolean;
};

export type Agent = {
  name: string;
  description?: string;
  running: boolean;
  suspended: boolean;
  rig?: string;
  pool?: string;
  session?: SessionInfo;
  active_bead?: string;
  provider?: string;
  display_name?: string;
  state: string;
  available: boolean;
  unavailable_reason?: string;
  last_output?: string;
  activity?: string;
  model?: string;
  context_pct?: number;
  context_window?: number;
};

export type BeadDep = {
  issue_id: string;
  depends_on_id: string;
  type: string;
};

export type Bead = {
  id: string;
  title: string;
  status: string;
  issue_type: string;
  priority?: number;
  created_at?: string;
  updated_at?: string;
  assignee?: string;
  parent?: string;
  description?: string;
  notes?: string;
  labels?: string[];
  metadata?: Record<string, string>;
  dependencies?: BeadDep[];
};

export type GcEvent = {
  seq: number;
  type: string;
  ts: string;
  actor?: string;
  subject?: string;
  message?: string;
  payload?: unknown;
};

export type Order = {
  name: string;
  scoped_name?: string;
  description?: string;
  type?: string;
  gate?: string;
  check?: string;
  formula?: string;
  pool?: string;
  timeout_ms?: number;
  enabled?: boolean;
  capture_output?: boolean;
};

export type Rig = {
  name: string;
  path?: string;
  suspended?: boolean;
  agent_count?: number;
  running_count?: number;
  last_activity?: string;
};
