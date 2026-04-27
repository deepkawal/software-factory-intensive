export type SfiLabel = {
  key: string;
  title: string;
  description: string;
  accent: string;
};

export const SFI_LABELS: SfiLabel[] = [
  {
    key: "needs-plan",
    title: "Needs Plan",
    description: "Awaiting Planner",
    accent: "bg-sky-500/15 text-sky-300 border-sky-500/40",
  },
  {
    key: "needs-architecture",
    title: "Needs Architecture",
    description: "Awaiting Architect",
    accent: "bg-indigo-500/15 text-indigo-300 border-indigo-500/40",
  },
  {
    key: "needs-design",
    title: "Needs Design",
    description: "Awaiting Designer",
    accent: "bg-fuchsia-500/15 text-fuchsia-300 border-fuchsia-500/40",
  },
  {
    key: "ready-to-build",
    title: "Ready to Build",
    description: "Awaiting Coder",
    accent: "bg-amber-500/15 text-amber-300 border-amber-500/40",
  },
  {
    key: "needs-review",
    title: "Needs Review",
    description: "Awaiting Reviewer",
    accent: "bg-orange-500/15 text-orange-300 border-orange-500/40",
  },
  {
    key: "needs-deploy",
    title: "Needs Deploy",
    description: "Awaiting Deployer",
    accent: "bg-emerald-500/15 text-emerald-300 border-emerald-500/40",
  },
];

export const SFI_AUX_LABELS: SfiLabel[] = [
  {
    key: "needs-pm",
    title: "Needs PM",
    description: "Awaiting PM",
    accent: "bg-cyan-500/15 text-cyan-300 border-cyan-500/40",
  },
  {
    key: "needs-tests",
    title: "Needs Tests",
    description: "Awaiting Validator",
    accent: "bg-teal-500/15 text-teal-300 border-teal-500/40",
  },
  {
    key: "needs-improve",
    title: "Needs Improve",
    description: "Awaiting Improver",
    accent: "bg-violet-500/15 text-violet-300 border-violet-500/40",
  },
];

export const ALL_SFI_LABELS = [...SFI_LABELS, ...SFI_AUX_LABELS];
export const SFI_LABEL_KEYS = ALL_SFI_LABELS.map((l) => l.key);
export const labelByKey = Object.fromEntries(
  ALL_SFI_LABELS.map((l) => [l.key, l]),
) as Record<string, SfiLabel>;

export function pickPrimaryLabel(labels: string[] | undefined): string | null {
  if (!labels?.length) return null;
  for (const l of SFI_LABEL_KEYS) {
    if (labels.includes(l)) return l;
  }
  return null;
}
