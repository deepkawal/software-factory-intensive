export type PipelineRole = {
  key: string;
  title: string;
  blurb: string;
};

export const SFI_PIPELINE: PipelineRole[] = [
  { key: "planner", title: "Planner", blurb: "Drafts work packages from intent" },
  { key: "architect", title: "Architect", blurb: "Owns ADRs and design choices" },
  { key: "designer", title: "Designer", blurb: "Writes the spec and UI" },
  { key: "builder", title: "Coder", blurb: "Writes the code" },
  { key: "reviewer", title: "Reviewer", blurb: "Quality + security gate" },
  { key: "deployer", title: "Deployer", blurb: "Release gate + ship" },
];

export const SFI_AUX_ROLES: PipelineRole[] = [
  { key: "supervisor", title: "Supervisor", blurb: "Watches the factory" },
  { key: "improver", title: "Improver", blurb: "Continuous improvement" },
  { key: "validator", title: "Validator", blurb: "QA / acceptance" },
  { key: "pm", title: "PM", blurb: "Project tracking" },
];

export const PIPELINE_KEYS = SFI_PIPELINE.map((r) => r.key);

export function matchRole(
  agentName: string,
  pool?: string,
): string | null {
  const haystack = `${agentName} ${pool ?? ""}`.toLowerCase();
  for (const r of [...SFI_PIPELINE, ...SFI_AUX_ROLES]) {
    if (haystack.includes(r.key)) return r.key;
  }
  return null;
}

export function pipelineIndex(roleKey: string): number {
  return SFI_PIPELINE.findIndex((r) => r.key === roleKey);
}
