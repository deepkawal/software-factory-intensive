# L3 · Deploy Designer + Coder Agents

> **What you'll build:** Two more specialized AI agents managed by Gas City — a Designer that turns the work package + ADR from L2 into a concrete component spec, and a Coder that reads the spec and produces a committed implementation with passing tests. By the end of this lab, you'll have extended your L2 pipeline with two more stages and shipped a working feature branch.

| | |
|---|---|
| **Estimated duration** | ~75 minutes |
| **Type** | LAB |
| **Deliverable** | Working Designer + Coder agents, one component spec at `design/<slug>-spec.md`, and committed implementation code with at least 2 passing test cases |

---

## Session workspace note

The implementation agent is the `builder` pack at `../../../packs/builder/`, with its prompt at `packs/builder/agents/builder/prompt.template.md`. Some curriculum narrative uses the word "Coder" as the role name — it refers to the same agent.

**Where your work goes this session:**
* Session deliverables → `../../../activities/labs/L3/` (the activity folder for L3)
* Customised pack copies (if you deviate from shipped defaults) → `../../../activities/labs/L3/packs/<agent>/`
* The shipped Designer + Builder are already composed into every rig via `default_rig_includes = ["../packs/all"]` in `my-factory/city.toml.template`. To swap in your customised copies, add rig-scoped imports to `my-factory/city.toml` (e.g. `[rigs.imports.designer] source = "../activities/labs/L3/packs/designer"`). See [`activities/labs/L3/README.md`](../../../activities/labs/L3/README.md) for exact lines.

If you skipped an earlier lab or a prompt edit breaks the pack, remove any `[rigs.imports.<name>]` block pointing at your customised copy from `my-factory/city.toml` and run `gc restart` — the rig falls back to the shipped pack via `default_rig_includes = ["../packs/all"]`, which always passes `gc doctor`.

---

## Architecture Diagram

```
                    ┌───────────────────────────┐
                    │  Work Package + ADR         │
                    │  (from L2, already           │
                    │   committed)                 │
                    └─────────────┬─────────────┘
                                  │
                                  ▼
                    ┌───────────────────────────┐
                    │      DESIGNER AGENT        │
                    │                            │
                    │  Reads:                     │
                    │    • bead description       │
                    │    • work-packages/<slug>.md│
                    │    • docs/adr/NNNN-<slug>.md│
                    │    • docs/PROJECT_MANIFEST  │
                    │    • agents/designer/prompt  │
                    │                            │
                    │  Produces:                  │
                    │    design/<slug>-spec.md    │───► Purpose, Location,
                    │                            │     Props, State, Layout,
                    └─────────────┬─────────────┘     Interactions, Edge Cases
                                  │
                    ┌─────────────▼─────────────┐
                    │       CODER AGENT          │
                    │                            │
                    │  Reads:                     │
                    │    • design/<slug>-spec.md  │
                    │    • work-packages/<slug>.md│
                    │    • docs/adr/NNNN-<slug>.md│
                    │    • docs/PROJECT_MANIFEST  │
                    │    • CLAUDE.md (tailored)   │
                    │    • agents/builder/prompt    │
                    │                            │
                    │  Produces:                  │
                    │    src/<Location>/*.ts(x)   │───► Implementation files,
                    │    + tests committed on      │     tests, feature branch
                    │    feature branch            │     commits
                    └───────────────────────────┘
```

---

## Prerequisites

Before starting this lab, verify each of these:

| Prerequisite | How to verify | If it's missing |
|-------------|---------------|-----------------|
| L2 complete | `ls ~/path/to/your-repo/work-packages/` and `ls ~/path/to/your-repo/docs/adr/` both return files | Go back and complete L2. The Designer reads those artifacts as its primary input. |
| Both L2 beads closed | `bd list --status closed` shows the Planner + Architect beads | Run `bd close <bead-id>` for any still open. |
| Gas City running | `gc status` shows `your-repo/planner.planner` and `your-repo/architect.architect` | `gc restart`; if that doesn't bring them back, confirm `default_rig_includes = ["../packs/all"]` is present in `my-factory/city.toml`. |
| Feature branch checked out | `git branch --show-current` shows `l2-planner-architect` (or equivalent) | `git checkout l2-planner-architect`. You'll add Designer and Coder commits on the same branch. |
| Project Manifest | `cat ~/path/to/your-repo/docs/PROJECT_MANIFEST.md` → filled in | This lab assumes L1 + L2 already populated it. If empty, fill it before continuing. |
| (Recommended) Tailored ADRs | `grep -i "tailored" ~/path/to/your-repo/CLAUDE.md` finds content | If you skipped `actual adr-bot` in L2, run it now — the Coder reads `CLAUDE.md` too. |

---

## Gas City Capabilities Used This Lab

| Command | What it does | Used in step |
|---------|--------------|--------------|
| `gc status` | Confirm the shipped Designer + Builder are already composed into your rig via `packs/all` | Part 1, Part 2 |
| `gc restart` | Reload city configuration if you add a rig-scoped import for a customised pack copy | Part 1, Part 2 |
| `gc status` | Confirm which agents are live | Part 1, Part 2 |
| `bd create --deps blocks:<bead>` | Chain the Designer bead after L2 outputs | Part 3 |
| `gc sling --nudge your-project/designer.designer <bead>` | Route a bead to the Designer and wake its session | Part 3 |
| `gc sling --nudge your-project/builder.builder <bead>` | Route a bead to the Builder (longer-running) | Part 4 |
| `gc session peek <target>` | Snapshot the agent's current output without attaching | Parts 3, 4 |
| `gc session attach <target>` | Attach to the agent's live tmux session (don't type into it) | Parts 3, 4 |
| `gc events --follow` | Stream all city events from another terminal | Part 4 |
| `bd close <bead>` | Mark a bead done after its artifact is committed | Parts 3, 4 |

---

## The Use Case: Loyalty Points for Fired Up Pizza (continued)

This lab continues the running example from L2: **adding a loyalty points system to Fired Up Pizza**. L2 produced two artifacts you'll consume here:

- `work-packages/loyalty-points-system.md` — goal, stories, acceptance criteria, test cases, scope
- `docs/adr/0001-loyalty-points-storage.md` — the decision to use a `points_ledger` table

This lab's deliverable is the first customer-facing piece of that feature: **a loyalty points badge component** that shows a customer's current balance on the order confirmation page. The component is small enough to ship in 75 minutes but real enough to exercise typing, state, API integration, and edge cases (empty, loading, error).

If you're working against your own project, pick a small component or API endpoint from your L2 work package — something with typed props, one to three interactions, and at least one async concern (fetch, mutation, or side effect).

---

## Part 0: Read the Shipped Packs (~5 min)

Before installing anything, read what you're about to install. Designer and Coder packs follow the same pattern as Planner and Architect — `pack.toml` for metadata, a prompt file as the agent's personality, and an overlay directory for environment overrides.

### Step 1: Open the Designer Pack Metadata

Open this file and read it end-to-end — it's 14 lines:

[`packs/designer/pack.toml`](../../../packs/designer/pack.toml)

```toml
[pack]
name = "actual-designer"
schema = 2
```

Plus `packs/designer/agents/designer/agent.toml`:

```toml
scope = "rig"
wake_mode = "fresh"
work_dir = ".gc/agents/{{.Rig}}/designer"
nudge = "Run 'gc prime', then check bd ready --label=needs-design for work."
idle_timeout = "2h"
min_active_sessions = 0
max_active_sessions = 1
```

**What's happening here:** Same shape as the Planner and Architect pack files you read in L2 — `pack.toml` identifies the pack; `agents/<name>/agent.toml` configures the agent. `max_active_sessions = 1` means the Designer handles one bead at a time — this is deliberate, because spec quality drops when the Designer is context-switching between features.

### Step 2: Open the Designer Prompt

Open this file and read it end-to-end — it's ~75 lines:

[`packs/designer/agents/designer/prompt.template.md`](../../../packs/designer/agents/designer/prompt.template.md)

You should see the familiar six-section structure:

```
# Designer Agent

## Role              ← "You receive work packages and ADRs, and produce
                        component specifications that the Coder agent can
                        implement without ambiguity."

## Inputs            ← work-packages/<slug>.md + docs/adr/<file>.md
                        + docs/PROJECT_MANIFEST.md

## Output Format     ← design/<feature-slug>-spec.md with 8 sections:
                        Purpose, Location, Props, State, Layout,
                        Interactions, Data Flow, Edge Cases, References

## Quality Gate      ← 4 rules: props/state typed, at least one interaction,
                        edge cases cover empty/error/loading, Location path
                        specified

## Process           ← 5 steps: read WP + ADR → read manifest → produce
                        spec → commit → mark bead ready for Coder

## Config Discipline ← "All your behavior comes from this prompt and the
                        project manifest. If your output quality needs to
                        change, the fix is updating this file — not
                        ad-hoc re-prompting."
```

Pay attention to one line in the Output Format section:

```markdown
## Location
`src/<path/to/component>` — where the implementation should live.
```

**What's happening here:** The Designer is required to pick a concrete destination path inside `src/` for the component. The Coder reads that path verbatim and writes there. This is the Designer/Coder handoff contract — a single string that tells the Coder where to put files. If the Designer picks the wrong path, the Coder builds in the wrong place. That's why the Quality Gate has an explicit "Location path is specified" rule.

### Step 3: Open the Coder Pack Metadata

[`packs/builder/pack.toml`](../../../packs/builder/pack.toml)

```toml
[pack]
name = "actual-builder"
schema = 2
```

Plus `packs/builder/agents/builder/agent.toml` (the curriculum calls this agent "Coder"; in the shipped packs the role is named `builder`):

```toml
scope = "rig"
wake_mode = "fresh"
work_dir = ".gc/agents/{{.Rig}}/builder"
nudge = "Run 'gc prime', then check bd ready --label=ready-to-build for work."
idle_timeout = "2h"
min_active_sessions = 0
max_active_sessions = 1
```

**What's happening here:** `idle_timeout = "2h"` matches the other agents. For production use you might raise `max_active_sessions` to 3 so the Coder can take multiple work packages in parallel — useful when the Planner has queued several. For this lab you'll run one at a time.

### Step 4: Open the Coder Prompt

Open this file and read it end-to-end — it's ~50 lines:

[`packs/builder/agents/builder/prompt.template.md`](../../../packs/builder/agents/builder/prompt.template.md)

Same six-section structure, with one extra section (`Rules`) unique to the Coder:

```
## Role              ← "You receive component specs from the Designer and
                        implement working code that passes the test cases
                        defined in the work package."

## Inputs            ← design/<slug>-spec.md + work-packages/<slug>.md
                        + docs/adr/ + docs/PROJECT_MANIFEST.md

## Output            ← Implementation files in src/ matching the spec's
                        Location field, tests passing the WP's test cases

## Quality Gate      ← 5 rules: every prop implemented, every interaction
                        works, edge cases handled, at least 2 WP test cases
                        pass, lint clean

## Process           ← 7 steps: read spec + WP → read ADR → implement at
                        Location → write tests → run lint/tests → commit →
                        mark ready for Reviewer

## Rules             ← Follow spec exactly, never modify files outside
                        feature scope, always on a feature branch

## Config Discipline ← Same message as other packs — fix the prompt, not
                        the output.
```

Notice rule #4 in the Quality Gate: **"At least 2 test cases from the work package pass."** This is the specific, measurable bar this lab cares about. It's how you know the Coder did real work, not just type-checked a stub.

You're done reading. Now install.

---

## Part 1: Verify the Designer Agent Is Ready (~10 min)

### Step 1: Confirm the Designer Is Composed Into Your Rig

```bash
# The Designer pack is already composed into every rig via
# default_rig_includes = ["../packs/all"] in my-factory/city.toml.template.
# For L3, there's no install step — just confirm it's there:
cd my-factory
gc status
```

You should see the Designer among the 8 agents from `packs/all`:

```
my-factory  /Users/you/.../my-factory
  Controller: standalone (PID <pid>)
  Suspended:  no

Agents:
  claude                           pool (min=0, max=unlimited)
  your-repo/claude                 pool (min=0, max=unlimited)
  your-repo/architect.architect    stopped
  your-repo/builder.builder        stopped
  your-repo/designer.designer      stopped
  your-repo/improver.improver      stopped
  your-repo/planner.planner        stopped
  your-repo/release-gate.release-gate  stopped
  your-repo/reviewer.reviewer      stopped
  your-repo/validator.validator    stopped
```

All 8 pipeline agents show as `stopped` until their first sling wakes them — `stopped` here means "no active session," not "broken." The Designer is ready to sling.

### Step 2: How the Designer Got Here (v2 Pack Discovery)

The Designer is defined at `packs/designer/agents/designer/agent.toml` + `packs/designer/agents/designer/prompt.template.md`. Agents are discovered by convention — any directory under `agents/` with either `prompt.md` or `prompt.template.md` IS an agent. The filesystem declares it; no TOML table registers it.

`packs/designer` is imported by the composition pack `packs/all` (binding name `designer`), which is imported by `my-factory/pack.toml` as `all`, which is composed into every rig via `default_rig_includes`. So by the time you run `gc status`, the Designer's agent.toml has been loaded, its prompt template discovered, and the rig-scoped instance `your-repo/designer.designer` is ready to sling.

The qualified name `designer.designer` reads as `<pack-binding>.<agent-name>` — the pack `packs/designer` (bound as `designer` inside `packs/all`) defines the agent `designer` (inside `agents/designer/`). Shipped packs use the same name for both for clarity. `your-repo/designer` works as shorthand when there's no ambiguity.

### Step 3 (Optional): Customise the Designer's Behavior

To override the shipped prompt or config for this rig, copy the pack locally and add a rig-scoped import:

```bash
cp -r ../packs/designer ../activities/labs/L3/packs/designer
# Edit ../activities/labs/L3/packs/designer/agents/designer/prompt.template.md
# Or edit agent.toml to adjust idle_timeout / max_active_sessions / etc.
```

Then add to `my-factory/city.toml`:

```toml
[[rigs]]
name = "your-repo"

[rigs.imports.designer]
source = "../activities/labs/L3/packs/designer"
```

And restart:

```bash
cd my-factory
gc restart
gc status     # the designer entry is now from your local copy
```

**What's happening here:** `[rigs.imports.designer]` binds YOUR pack copy as `designer` for this rig only. Other rigs in the city still use the shipped version. Rig-level imports override pack-level `default_rig_includes` bindings by name — a clean scoping rule that lets you iterate on one rig without affecting anyone else.

### Step 4: Customize the Designer Prompt for Your Project

The shipped prompt is generic. Two edits make it project-specific:

**a) Open `packs/designer/agents/designer/prompt.template.md` in your editor.**

**b) Update the Output Format's Location example** with your project's src layout. For a React/TypeScript feature-folder layout (Fired Up Pizza's convention per `docs/PROJECT_MANIFEST.md`):

Find this line:
```markdown
## Location
`src/<path/to/component>` — where the implementation should live.
```

Make the guidance explicit:
```markdown
## Location
`src/features/<feature-slug>/` for React components with co-located hooks,
types, and tests. Never write implementation files directly under `src/`
— always nest inside a feature folder. Test files go in
`src/features/<feature-slug>/__tests__/`.
```

**c) Add a project-specific Quality Gate rule.** Append one rule referencing a convention from `docs/PROJECT_MANIFEST.md`:

```markdown
## Quality Gate

A component spec is complete when:
1. Props/inputs and state are typed
2. At least one interaction is documented
3. Edge cases cover empty, error, and loading states
4. Location path is specified
5. All monetary values in props, state, and layout are in cents
   (not dollars) per project convention
```

For your own project, substitute rule 5 with something measurable from your manifest (e.g. "All database access is via the existing `db.ts` helper, never raw SQLite").

### Step 5: Commit Your Customization

```bash
cd ~/path/to/your-repo
git add -A
git commit -m "chore(designer): customize designer prompt for project conventions"
```

**Why commit now?** Same reason as L2: the diff between the shipped prompt and your edited version is your config-discipline evidence. If the Designer drifts later, `git log packs/designer/agents/designer/prompt.template.md` tells you exactly what changed and when.

---

## Part 2: Verify the Builder (Coder) Agent Is Ready (~10 min)

### Step 1: Confirm the Builder Is Composed Into Your Rig

```bash
cd my-factory
gc status | grep builder
```

The Builder (same role as the curriculum-level "Coder") is already shipped via `packs/all` and composed into every rig by `default_rig_includes`. You should see:

```
  your-repo/builder.builder        stopped
```

No install step — the Builder comes from `packs/all`, which is already composed into every rig.

### Step 2: How the Builder's Config Compares to Other Agents

Open `packs/builder/agents/builder/agent.toml`:

```toml
scope = "rig"
wake_mode = "fresh"
work_dir = ".gc/agents/{{.Rig}}/builder"
nudge = "Run 'gc prime', then check bd ready --label=ready-to-build for work."
idle_timeout = "3h"
min_active_sessions = 0
max_active_sessions = 1
```

**What's happening here:** `idle_timeout = "3h"` is longer than the other agents because real implementation — first-time install of npm dependencies, a typecheck, and a full test run — can take 15–45 minutes for a non-trivial component. The session shouldn't evict itself while the agent is mid-build.

To override agent config, ship a patch or a copy. If you want a different `idle_timeout` for Builder in this rig:

- **Copy-and-override** (simplest — same shape as the Designer customisation in Part 1):
  ```bash
  cp -r ../packs/builder ../activities/labs/L3/packs/builder
  # Edit ../activities/labs/L3/packs/builder/agents/builder/agent.toml
  ```
  Then add `[rigs.imports.builder] source = "../activities/labs/L3/packs/builder"` to `my-factory/city.toml` and `gc restart`.
- **Rig-scoped patch** (`[[rigs.patches]]` in city.toml, qualified-name targeted): a lighter-touch alternative that overrides only the fields that differ. See the agent-patches reference for the full syntax.

### Step 3: Restart and Verify

```bash
gc restart
gc status
```

You should see all 8 agents from `packs/all` — Planner, Architect, Designer, Builder, Reviewer, Validator, Release-Gate, Improver — plus the implicit `claude` and `codex`/`gemini` (if configured) at the city and rig scopes.

### Step 4: Customize the Coder Prompt for Your Project

Open `packs/builder/agents/builder/prompt.template.md` and make two edits:

**a) Add the project's quality-gate commands to the Quality Gate section.** The shipped prompt says "Code passes lint (`npm run lint` or equivalent)." Replace with exact commands from the project manifest. For a React/TypeScript project:

```markdown
## Quality Gate

Code is complete when:
1. Every prop/input from the spec is implemented
2. Every interaction from the spec works
3. Edge cases (empty, error, loading) are handled
4. At least 2 test cases from the work package pass
5. Code passes all of these commands without errors:
   - `npm run typecheck`
   - `npm run lint`
   - `npm test`
```

**b) Add a reference-the-manifest instruction** to the Process section. Find:

```markdown
1. Read the component spec and work package from your bead
2. Read the ADR for technical constraints
```

Expand to:

```markdown
1. Read the component spec and work package from your bead
2. Read the ADR for technical constraints
3. Read `docs/PROJECT_MANIFEST.md` for conventions — test framework, CSS
   approach, state management, linting rules, commit message style
4. Read `CLAUDE.md` for any tailored ADR baselines — these are binding
   unless the Designer's spec explicitly overrides them
```

Renumber the remaining steps.

**What's happening here:** Making manifest-reading explicit forces the Coder to internalize conventions *before* writing code. Without this step, you'll see the Coder write Jest tests in a project that uses Vitest, or Tailwind classes in a project using CSS Modules — because the Coder defaulted to common patterns instead of reading your project's actual setup.

### Step 5: Commit Your Customization

```bash
cd ~/path/to/your-repo
git add -A
git commit -m "chore(coder): customize coder prompt with project quality gates"
```

---

## Part 3: Create and Run the Designer (~20 min)

The Designer's inputs are the work package and ADR from L2. You'll chain a new bead after the Architect bead from L2 and sling it to the Designer.

### Step 1: Create the Designer Bead

```bash
cd my-factory
bd create "Design: Loyalty Points Badge Component" \
  --description "$(cat <<'EOF'
Produce a component spec for the Loyalty Points Badge — the first user-facing
piece of the loyalty points feature. It shows a customer's current point
balance on the order confirmation page.

Inputs:
- Work package: work-packages/loyalty-points-system.md
- ADR: docs/adr/0001-loyalty-points-storage.md
- Project manifest: docs/PROJECT_MANIFEST.md

Requirements:
1. Use Story 2 from the work package ("View Points Balance") as the scope
2. Define typed props (customer id is required)
3. Specify Location under src/features/loyalty-points/
4. Document empty, loading, and error states
5. Reference the ADR's points_ledger schema in the Data Flow section

Output: design/loyalty-points-badge-spec.md
EOF
)" \
  --deps blocks:my-factory-d4e5f6
```

Replace `my-factory-d4e5f6` with your L2 Architect bead ID (from `bd list`).

You should see:

```
Created bead: my-factory-design123
```

Note this bead ID — you'll sling it next.

**What's happening here:** `--deps blocks:` is optional here (the Architect bead is already closed), but including it preserves the dependency chain in your bead graph. Later, when you look at the provenance of `design/loyalty-points-badge-spec.md`, you can walk backward from this bead to the Architect bead to the Planner bead and see the full history of who decided what.

### Step 2: Sling the Bead to the Designer

```bash
gc sling --nudge your-repo/designer.designer my-factory-design123
```

You should see:

```
Slinging my-factory-design123 → designer
Session started: designer-design123 (tmux)
```

**What's happening here:** Gas City started a tmux session, launched Claude Code inside your repo, loaded `packs/designer/agents/designer/prompt.template.md` as the system prompt, and handed the bead's description as the task. The Designer is now autonomous.

### Step 3: Watch the Designer Work

```bash
gc session peek your-repo/designer.designer
```

You'll see the session streaming in real-time. The Designer should:

1. Read `docs/PROJECT_MANIFEST.md`
2. Read `work-packages/loyalty-points-system.md`
3. Read `docs/adr/0001-loyalty-points-storage.md`
4. Start writing `design/loyalty-points-badge-spec.md`
5. Commit the spec on your feature branch

Press `Ctrl+b d` to detach from tmux; the agent continues. Monitor progress from another terminal:

```bash
gc events --follow            # stream all city events
gc status                     # designer state: working → idle
bd show my-factory-design123     # bead status
```

Typical runtime: 2–4 minutes.

### Step 4: Review the Spec

```bash
cd ~/path/to/your-repo
cat design/loyalty-points-badge-spec.md
```

You should see a file with this structure (content will vary):

```markdown
# Component Spec: LoyaltyPointsBadge

## Purpose
Display a customer's current loyalty point balance on the order confirmation
page with contextual messaging about what they can redeem.

## Location
`src/features/loyalty-points/LoyaltyPointsBadge.tsx`
Tests: `src/features/loyalty-points/__tests__/LoyaltyPointsBadge.test.tsx`
Hook:  `src/features/loyalty-points/useLoyaltyBalance.ts`
Types: `src/features/loyalty-points/types.ts`

## Props / Inputs
| Name       | Type    | Required | Description                                 |
|------------|---------|----------|---------------------------------------------|
| customerId | string  | yes      | The customer whose balance to display        |
| compact    | boolean | no       | If true, render only the numeric balance     |

## State
| Name     | Type                               | Initial    | Description                |
|----------|------------------------------------|------------|----------------------------|
| balance  | number                             | 0          | Current points balance      |
| status   | "idle" \| "loading" \| "error"     | "loading"  | Request lifecycle state     |

## Layout
```
┌──────────────────────────────┐
│  Points: 340                 │
│  Redeem 100 for $5 off       │
└──────────────────────────────┘
```
Compact mode renders only the numeric balance (no redemption line).

## Interactions
- On mount: fetch balance via `useLoyaltyBalance(customerId)`
- On successful order completion event: refetch balance

## Data Flow
Balance is derived from the `points_ledger` table (per ADR-0001) via
`GET /api/customers/:id/points`. The hook aggregates positive + negative
ledger entries server-side and returns a single integer. The component
never computes balance client-side.

## Edge Cases
- Empty state: new customer with zero points → render "0 points · earn 1
  per dollar spent"
- Loading state: render a subtle skeleton at the same width
- Error state: render "Points unavailable" and log to the error pipeline
  (do not block the order confirmation page)

## References
- work-packages/loyalty-points-system.md
- docs/adr/0001-loyalty-points-storage.md
```

### Step 5: Check the Spec Against the Quality Gate

Open `packs/designer/agents/designer/prompt.template.md` and walk the Quality Gate rules:

| Quality Gate Rule | Pass? | Evidence |
|-------------------|-------|----------|
| Props/inputs and state are typed | check | Every row in the Props and State tables has a Type column filled in |
| At least one interaction documented | check | At least one bullet in the Interactions section |
| Edge cases cover empty, error, loading | check | Three bullets under Edge Cases, one for each |
| Location path is specified | check | A line starting with `src/...` in the Location section |

**If any rule fails:**

1. **Do NOT edit the spec file directly.** That breaks config discipline.
2. Open `packs/designer/agents/designer/prompt.template.md` and add a more specific rule. For example, if the Location is too vague:

```markdown
## Quality Gate
...
6. Location must name concrete file paths — no placeholders like
   `<path>` or `TBD`. Include the primary component file, the test
   file, and any co-located hook/type files.
```

3. Delete the spec and re-sling:

```bash
rm design/loyalty-points-badge-spec.md
gc sling --nudge your-repo/designer.designer my-factory-design123
gc session peek your-repo/designer.designer
```

4. Review the new output. Repeat until all rules pass.

**Target: one sling.** Spec iteration is usually faster than work-package iteration because the constraints are more concrete.

### Step 6: Close the Designer Bead

```bash
bd close my-factory-design123 --comment "Component spec committed: design/loyalty-points-badge-spec.md"
```

---

## Part 4: Create and Run the Coder (~25 min)

The Coder's inputs are the spec you just produced plus the original work package (for test cases) and ADR (for technical constraints).

### Step 1: Create the Coder Bead

```bash
cd my-factory
bd create "Implement: Loyalty Points Badge Component" \
  --description "$(cat <<'EOF'
Implement the Loyalty Points Badge component per the design spec.

Inputs:
- Component spec: design/loyalty-points-badge-spec.md
- Work package: work-packages/loyalty-points-system.md (for test cases)
- ADR: docs/adr/0001-loyalty-points-storage.md (for data model)
- Project manifest: docs/PROJECT_MANIFEST.md (for conventions)
- CLAUDE.md (for tailored baselines)

Requirements:
1. Implement at the Location paths from the spec
2. Use the typed props and state definitions from the spec verbatim
3. Handle all three edge cases (empty, loading, error)
4. Write tests that cover the work package's Story 2 test cases
5. At least 2 test cases from the work package must pass
6. Pass npm run typecheck, npm run lint, and npm test before committing

Commit on the existing feature branch. Use conventional-commit messages
per the tailored ADR baselines.
EOF
)" \
  --deps blocks:my-factory-design123
```

You should see:

```
Created bead: my-factory-impl456
```

### Step 2: Sling the Bead to the Coder

```bash
gc sling --nudge your-repo/builder.builder my-factory-impl456
```

You should see:

```
Slinging my-factory-impl456 → coder
Session started: coder-impl456 (tmux)
```

### Step 3: Watch the Coder Work

```bash
gc session peek your-repo/builder.builder
```

The Coder should:

1. Read `design/loyalty-points-badge-spec.md`
2. Read `work-packages/loyalty-points-system.md`
3. Read `docs/adr/0001-loyalty-points-storage.md`
4. Read `docs/PROJECT_MANIFEST.md`
5. Read `CLAUDE.md` (for tailored baselines)
6. Create `src/features/loyalty-points/types.ts`
7. Create `src/features/loyalty-points/useLoyaltyBalance.ts`
8. Create `src/features/loyalty-points/LoyaltyPointsBadge.tsx`
9. Create `src/features/loyalty-points/__tests__/LoyaltyPointsBadge.test.tsx`
10. Run `npm run typecheck`, `npm run lint`, `npm test` and fix until green
11. Commit with a conventional-commit message on the feature branch

Typical runtime: 10–25 minutes, depending on how many build/test cycles it takes to converge.

Detach with `Ctrl+b d`. Monitor from another terminal:

```bash
gc events --follow
gc status
```

Wait until the Coder's state returns to `idle`.

### Step 4: Review the Implementation

```bash
cd ~/path/to/your-repo
git log --oneline | head -10
```

You should see new commits at the top, e.g.:

```
f4d3c2b feat(loyalty-points): add LoyaltyPointsBadge component with balance fetching
b8a7c1d test(loyalty-points): add badge component tests for Story 2 acceptance
3e5f6a9 chore(coder): customize coder prompt with project quality gates
... (earlier L2 commits)
```

Look at the full diff from the start of this lab:

```bash
git diff main -- src/features/loyalty-points/
```

You should see four new files (types, hook, component, tests) inside the feature folder the Designer specified. Scan for three things:

1. **The component file implements every prop from the spec** — do a quick name-match: if the spec said `customerId: string`, the component should declare `customerId: string` (not `userId`, not optional).
2. **The tests reference the work package by name** — test descriptions should echo the Story 2 acceptance criteria ("shows 0 points for a new customer", "shows the correct balance for an existing customer", "renders a loading state while fetching").
3. **The test file has at least 2 `it(...)` / `test(...)` blocks** — this is the measurable Quality Gate bar.

### Step 5: Run the Quality Gates Manually

```bash
cd ~/path/to/your-repo
npm run typecheck
npm run lint
npm test -- --run src/features/loyalty-points/
```

All three should exit zero. If any fails, the Coder's commit was premature — move to Part 5.

### Step 6: Close the Coder Bead

Once the quality gates pass:

```bash
bd close my-factory-impl456 --comment "Implementation committed on feature branch; tests pass"
```

---

## Part 5: Run Tests & Iterate Via Config (~10 min)

This is the core discipline section. Quality gate failures happen — the fix is *never* to edit code by hand, and *never* to paste corrections into the Coder's tmux session. The fix is always a prompt edit followed by a re-sling.

Below are two realistic scenarios. Work through the flow for any that apply to your run.

### Scenario 1: Tests fail because the Coder used the wrong test framework

**What you see:**

```
$ npm test
sh: vitest: command not found
Error: Cannot find module 'jest'
```

The Coder wrote `import { describe, it, expect } from 'jest';` but the project's `package.json` uses Vitest.

**What NOT to do:**

- Open the test file and change `'jest'` to `'vitest'` by hand
- Tell the tmux session "hey, this project uses vitest, fix it"
- Re-sling with a longer bead description

**What to do:** Update `packs/builder/agents/builder/prompt.template.md` so the *next* feature doesn't hit this problem. Add to the Process section:

```markdown
## Process
...
3. Before writing any test file, run `cat package.json | grep -E '"(test|vitest|jest|mocha)"'`
   and use the test framework declared there. Never assume. Never default
   to Jest.
```

Then:

```bash
git add packs/builder/agents/builder/prompt.template.md
git commit -m "chore(coder): require explicit test-framework detection"

rm -r src/features/loyalty-points/
gc sling --nudge your-repo/builder.builder my-factory-impl456
gc session peek your-repo/builder.builder
```

**Why this works:** The fix lives in the Coder's system prompt, so every future bead inherits it. The next feature won't have to learn this lesson twice.

### Scenario 2: Tests pass but file structure doesn't match the spec

**What you see:** `npm test` passes, but the Coder wrote `src/components/LoyaltyBadge.tsx` instead of `src/features/loyalty-points/LoyaltyPointsBadge.tsx`. The Designer specified the feature-folder path; the Coder flattened it.

**What NOT to do:** Move the files manually with `git mv`.

**What to do:** Update `packs/builder/agents/builder/prompt.template.md` Rules section:

```markdown
## Rules

- Follow the spec exactly. If the spec is wrong, note it but implement as written.
- Open the component spec's Location section and list every file path it
  declares. If a file you want to create is not in that list, stop — do
  not invent structure. Create exactly the paths the Designer specified.
- Never modify files outside the scope of your bead's feature.
- If you need a dependency, add it via package manager and document in
  the commit.
- All code changes must be on a feature branch, never directly on main.
```

Then:

```bash
git add packs/builder/agents/builder/prompt.template.md
git commit -m "chore(coder): require literal adherence to spec Location paths"

# Back out the wrong-location commit
git reset --hard HEAD~1    # only if the Coder committed on a feature branch
# OR: if the wrong files are unstaged, just `rm` them

gc sling --nudge your-repo/builder.builder my-factory-impl456
gc session peek your-repo/builder.builder
```

### Scenario 3 (bonus): Coder skips the empty-state edge case

If the Coder implemented loading and error but silently dropped the empty state, the fix is in the Designer prompt, not the Coder prompt. The Designer's spec should have been explicit enough that a skipped state is a flag the Coder sees. Update `packs/designer/agents/designer/prompt.template.md` Output Format:

```markdown
## Edge Cases
- Empty state: what shows when there's no data (always required — every
  component has an empty state; if you think yours doesn't, describe what
  the first-render-no-data case looks like)
- Error state: what shows on failure
- Loading state: what shows during fetch
```

Re-sling the Designer (then the Coder). This is also why the Designer and Coder sit in separate agents with separate prompts: some fixes belong upstream, some downstream. Knowing which is half the skill.

### The Runs-to-Passing Target

Track your runs. A healthy L3 converges in **≤3 Coder slings**. Sling count = 1 means the shipped prompt plus your one customization was enough. Sling count = 5+ means your prompts are fighting your project's existing conventions — time to stop and read your own `docs/PROJECT_MANIFEST.md` for gaps.

---

## Inline Insight: Why the Designer Sits Between Architect and Coder

You might wonder why the pipeline needs a Designer at all — couldn't the Coder read the work package and ADR directly? In practice, that loses quality for three reasons:

1. **Work packages describe user-facing behavior, not component shape.** A work package says "customer sees their balance." It doesn't say "a React component named `LoyaltyPointsBadge` with a `customerId: string` prop and a three-state status enum." The Designer's job is to bridge the gap — taking ambiguous acceptance criteria and producing unambiguous component contracts.

2. **ADRs describe technical decisions at a different level.** An ADR says "use a points_ledger table." It doesn't say "call it through a hook named `useLoyaltyBalance` that returns `{ balance, status }`." The Designer translates data-model decisions into API-shaped consumption patterns.

3. **Specs are cheaper to iterate than code.** When your Coder produces the wrong output, it's faster to re-sling a 200-line spec than to re-sling a 2,000-line implementation. The Designer acts as a compression layer — any ambiguity that would have burned a whole Coder run gets caught in a two-minute Designer re-sling instead.

If you ever hit a project where the Designer feels redundant (e.g. "the work package already says exactly what to build"), that's a sign your Planner is overreaching. Pull component-shape details *out* of the work package and let the Designer own them.

## Inline Insight: Why the Coder Reads the Project Manifest Every Time

One rule shows up in every agent's Process section: "Read `docs/PROJECT_MANIFEST.md`." The Coder is the one where skipping this step hurts most.

The manifest contains answers that can't be derived from the spec alone: which test framework, which CSS approach, which state library, which file naming convention, which commit-message style, which linting rules, which package manager. Each of these is a defaulted choice the Coder will make *somehow* — and the default will almost always be wrong for a non-generic project.

Making manifest-reading explicit in the Coder prompt forces the agent to pull in those answers *before* writing code. This is why Part 2 Step 4 added `"Read docs/PROJECT_MANIFEST.md for conventions"` to the Process section. Without that line, you'll see the Coder default to Jest in a Vitest project, Tailwind in a CSS-Modules project, or MobX in a Redux project — each requiring a full re-sling.

## Inline Insight: Config Changes Compound Across Agents

When you fix a Coder issue in `packs/builder/agents/builder/prompt.template.md`, that fix applies to every future feature the Coder touches — including ones no one has thought of yet. This is the compounding return on config discipline: every prompt edit pays down a class of failures, not a single instance. A chat-based "just fix it this time" correction pays down *only* the single instance, and the next bead re-encounters the same failure. Over a factory lifetime (dozens to hundreds of features), the gap between these two strategies is enormous. This is why the Quality Bar below includes "Zero manual code edits" — it's the single most leveraged habit in the whole lab.

---

## Common Issues & Solutions

### Issue 1: Designer produces a spec without a Location path
**Symptom:** Spec has props, state, layout — but the Location section is empty or says `TBD`.
**Fix:** Add to `packs/designer/agents/designer/prompt.template.md` Quality Gate: "Location must name at least one concrete file path ending in a valid extension (`.tsx`, `.ts`, `.py`, `.go`). Never leave it as a placeholder." Re-sling.

### Issue 2: Designer produces a spec with untyped props
**Symptom:** Props table has `Name` and `Description` filled in but `Type` column is blank or says "any".
**Fix:** Add to `packs/designer/agents/designer/prompt.template.md` Quality Gate: "Every row in the Props and State tables must have a concrete type. Prohibited values in the Type column: `any`, `object`, `unknown`, empty string." Re-sling.

### Issue 3: Coder skips tests
**Symptom:** Implementation files exist, but no test file — or test file has zero `it(...)` blocks.
**Fix:** Add to `packs/builder/agents/builder/prompt.template.md` Process section: "You may not commit until `npm test` passes with at least 2 passing test cases that reference the work package's Story <N> acceptance criteria in their test descriptions." Re-sling.

### Issue 4: Coder writes code but doesn't commit
**Symptom:** `git status` shows uncommitted changes after the Coder session ends.
**Fix:** Add to `packs/builder/agents/builder/prompt.template.md` Process section: "After all quality gates pass, run `git add` and `git commit` before marking the bead ready. An uncommitted implementation is equivalent to no implementation." Re-sling.

### Issue 5: Coder writes files at the wrong location
**Symptom:** Files exist but under `src/components/` instead of `src/features/<slug>/`.
**Fix:** See Part 5 Scenario 2 above. Update the Rules section to require literal adherence to the spec's Location paths.

### Issue 6: Coder uses the wrong test framework
**Symptom:** Tests fail with `Cannot find module 'jest'` in a Vitest project (or vice versa).
**Fix:** See Part 5 Scenario 1 above. Require the Coder to inspect `package.json` before writing tests.

### Issue 7: Coder violates a tailored ADR from CLAUDE.md
**Symptom:** The tailored ADR says "use parameterized queries" and the Coder writes string-concatenation SQL.
**Fix:** Add to `packs/builder/agents/builder/prompt.template.md` Process section: "Before writing code, read the Tailored ADRs section of `CLAUDE.md`. Every decision in that section is binding unless the Designer's spec explicitly overrides it." Re-sling.

### Issue 8: Coder stalls on `npm install`
**Symptom:** The tmux session shows `npm install` running for 30+ minutes with no progress.
**Fix:** This is usually a network or registry issue, not a prompt issue. In another terminal: `cd ~/path/to/your-repo && npm install` manually, then `gc sling --nudge your-repo/builder.builder my-factory-impl456` again — the Coder will skip install if `node_modules/` is already present.

### Issue 9: `gc status` doesn't show `your-repo/designer.designer` or `your-repo/builder.builder` after restart
**Symptom:** Expected 8 pipeline agents, seeing fewer.
**Fix:** Confirm `default_rig_includes = ["../packs/all"]` is present in `my-factory/city.toml`, then `gc restart`. If you added a `[rigs.imports.designer]` or `[rigs.imports.builder]` block pointing at a customised copy, verify the path exists (`ls ../activities/labs/L3/packs/<agent>/pack.toml`).

### Issue 10: Coder produces code that passes tests but violates the spec
**Symptom:** `npm test` is green but the component has different prop names than the spec declared.
**Fix:** This is the most common failure mode in L3. Add to `packs/builder/agents/builder/prompt.template.md` Process section: "Before writing any source file, copy the Props table from the spec into a comment at the top of the component file. Your implementation must match those names and types exactly." Re-sling.

### Issue 11: Coder modifies files outside the feature folder
**Symptom:** The commit diff includes edits to `src/api/orders.ts` or `src/App.tsx` that you didn't expect.
**Fix:** Add to `packs/builder/agents/builder/prompt.template.md` Rules: "You may read any file in the repo. You may write only files inside the Location path from the spec. If you believe an external file must change for the feature to work, stop, append a `## Open Follow-ups` section to the spec noting what needs to change, and mark the bead blocked." Re-sling.

### Issue 12: The spec and the work package disagree on a requirement
**Symptom:** The work package says "earn 1 point per dollar spent" and the spec says "earn 1 point per $10 spent."
**Fix:** This is a Designer-side bug that the Coder inherited. Delete the spec, update `packs/designer/agents/designer/prompt.template.md` Process: "Before writing the spec, list every numeric value and quantifier from the work package's Goal and User Stories. Every one must appear verbatim in the spec." Re-sling the Designer, then the Coder.

---

## Quality Bar

When you review your own output, check:

- **Spec Completeness** — Purpose, Location, Props, State, Layout, Interactions, Data Flow, Edge Cases (all three states), and References all present. Every Props and State row has a concrete type.
- **Implementation Match** — Every file path the Designer declared exists at that path. Every prop name and type matches the spec verbatim. Every edge case from the spec has visible handling in the code.
- **Test Coverage** — At least 2 test cases from the work package pass. Test descriptions reference the work package's Story (e.g. "Story 2: shows 0 points for a new customer").
- **Quality Gates Green** — `npm run typecheck`, `npm run lint`, `npm test` all exit zero (or the equivalents for your stack).
- **Config Discipline** — Every iteration was a prompt-file diff plus a re-sling. Zero ad-hoc chat corrections. Zero manual code edits.

---

## Exit Criteria

Before leaving this lab, verify all of these:

- [ ] `gc status` shows `designer` and `coder` agents (in addition to L1 + L2 agents)
- [ ] `design/<slug>-spec.md` exists and is committed, with Layout + Props + State + Interactions + Edge Cases sections filled in
- [ ] Implementation code is committed at the spec's Location path
- [ ] At least 2 test cases from the work package are passing
- [ ] `npm run typecheck`, `npm run lint`, and `npm test` all pass (or equivalent for your stack)
- [ ] Zero manual code edits — all fixes were prompt updates to `packs/builder/agents/builder/prompt.template.md` or `packs/designer/agents/designer/prompt.template.md` followed by re-slings
- [ ] Both beads (Designer, Coder) are closed
- [ ] All changes pushed to remote

**L3 blocks L4.** Don't move on until the implementation is committed — L4's Reviewer agent reads the code and the spec together to produce review reports. Without a committed implementation, there's nothing to review.

---

## Suggestions Based on Project Type

- **React + TypeScript:** Update the Designer prompt to require TypeScript interface definitions for all props and "use Tailwind CSS class names in the Layout section" (or whatever your project uses). Update the Coder prompt to require `useState` for local state, `useQuery`/`useSWR` for async state (match the project's library), and that test files live next to source files under `__tests__/`.

- **Python backend:** Change the Designer's Output Format to produce API endpoint specs (method, path, request/response schema, status codes) instead of UI component specs. Change Location to a module path (`app/routes/loyalty.py`). Update the Coder prompt to require pytest fixtures and response-model pydantic validation.

- **Go services:** The Designer should produce interface definitions with explicit return types, and the spec's Location should be a package path (`internal/loyalty/`). Update the Coder prompt to require: "Return errors, not exceptions. Every exported function has a godoc comment. Test files end in `_test.go` and live in the same package."

- **Mobile (React Native / Flutter):** The Designer should produce screen specs with navigation actions, not web-component specs. Location should be a screen path (`screens/LoyaltyPointsScreen.tsx` or `lib/screens/loyalty_points_screen.dart`). The Coder prompt should specify the platform's idiomatic state management (MobX/Redux for React Native, Riverpod/Bloc for Flutter).

---

## Command Cheat Sheet

Every command you ran during this lab, in order:

```bash
# PART 0 — Read the packs (no commands — just read the files)

# PART 1 — Verify Designer (already composed via packs/all)
cd my-factory
gc status | grep designer   # your-repo/designer.designer stopped (expected before first sling)
# OPTIONAL: customise the Designer prompt for this project
# cp -r ../packs/designer ../activities/labs/L3/packs/designer
# # edit ../activities/labs/L3/packs/designer/agents/designer/prompt.template.md
# # Add rig-scoped import to my-factory/city.toml:
# #   [rigs.imports.designer]
# #   source = "../activities/labs/L3/packs/designer"
# gc restart
# gc status

# PART 2 — Verify Builder (already composed via packs/all)
gc status | grep builder    # your-repo/builder.builder stopped (expected)
# OPTIONAL: customise the Builder prompt for this project
# cp -r ../packs/builder ../activities/labs/L3/packs/builder
# # edit ../activities/labs/L3/packs/builder/agents/builder/prompt.template.md
# # (or edit agents/builder/agent.toml if you need a different idle_timeout, etc.)
# # Add rig-scoped import to my-factory/city.toml:
# #   [rigs.imports.builder]
# #   source = "../activities/labs/L3/packs/builder"
# gc restart
# cd ~/path/to/your-repo
# git add -A && git commit -m "chore(builder): customize builder prompt"

# PART 3 — Run the Designer
cd my-factory
bd create "Design: Loyalty Points Badge Component" \
  --description "..." --deps blocks:my-factory-d4e5f6
gc sling --nudge your-repo/designer.designer my-factory-design123
gc session peek your-repo/designer.designer                                # Ctrl+b d to detach
cat design/loyalty-points-badge-spec.md          # review output
# (if quality gate fails: edit prompt, rm spec, re-sling)
bd close my-factory-design123 --comment "Component spec committed"

# PART 4 — Run the Coder
bd create "Implement: Loyalty Points Badge Component" \
  --description "..." --deps blocks:my-factory-design123
gc sling --nudge your-repo/builder.builder my-factory-impl456
gc session peek your-repo/builder.builder                                   # longer run — 10–25 min
cd ~/path/to/your-repo
git log --oneline | head -10                     # verify commits
npm run typecheck && npm run lint && npm test    # quality gates
# (if quality gate fails: edit prompt, reset/rm files, re-sling)
bd close my-factory-impl456 --comment "Implementation committed; tests pass"

# PART 5 — Commit prompt changes and push
cd ~/path/to/your-repo
git push
```

---

## Quick Reference: What You Built

| Component | File / Location | What It Does |
|-----------|-----------------|--------------|
| Designer pack | `packs/designer/` | Defines the Designer agent: prompt, overlay, metadata |
| Designer prompt | `packs/designer/agents/designer/prompt.template.md` | System prompt for the Designer — Role, Inputs, Output Format, Quality Gate, Process, Config Discipline |
| Coder pack | `packs/builder/` | Defines the Coder agent: prompt, overlay, metadata |
| Coder prompt | `packs/builder/agents/builder/prompt.template.md` | System prompt for the Coder — same six-section structure plus a Rules section |
| Component spec | `design/<slug>-spec.md` | Designer's output: Purpose, Location, Props, State, Layout, Interactions, Data Flow, Edge Cases, References |
| Implementation | `src/<Location from spec>/` | Coder's output: typed implementation, co-located tests, matching the spec verbatim |
| Feature-branch commits | `git log feature-branch --oneline` | Conventional-commit history showing Designer commit + Coder commits |
| Designer bead | `bd show my-factory-design123` | Work item that triggered the Designer, chained after the Architect bead |
| Coder bead | `bd show my-factory-impl456` | Work item that triggered the Coder, chained after the Designer bead |
| Passing tests | `npm test` output | Proof of Quality Gate rule 4: at least 2 work-package test cases pass |

---

## Your Final File Structure

After completing L3, your project repo should contain:

```
your-repo/
├── CLAUDE.md                                         # (unchanged from L2)
├── DECISIONS.md                                      # (unchanged from L2 for now)
├── docs/
│   ├── PROJECT_MANIFEST.md
│   └── adr/
│       └── 0001-loyalty-points-storage.md            # L2 Architect output
├── work-packages/
│   └── loyalty-points-system.md                      # L2 Planner output
├── design/
│   └── loyalty-points-badge-spec.md                  # ← L3 Designer output
├── src/
│   ├── main.tsx                                      # (pre-existing)
│   └── features/
│       └── loyalty-points/                           # ← L3 Coder output
│           ├── LoyaltyPointsBadge.tsx
│           ├── useLoyaltyBalance.ts
│           ├── types.ts
│           └── __tests__/
│               └── LoyaltyPointsBadge.test.tsx
├── review-reports/.gitkeep                           # Empty — Reviewer fills this in L4
├── release-gates/.gitkeep                            # Empty — Deployer fills this in L4
└── feedback-loops/.gitkeep                           # Empty — W4 fills this in
```

And your city:

```
my-factory/
├── city.toml                                         # Workspace provider + rigs; agents come from packs/all
└── beads/
    ├── my-city-a1b2c3 (closed)                      # L2 Planner bead
    ├── my-factory-d4e5f6 (closed)                      # L2 Architect bead
    ├── my-factory-design123 (closed)                   # L3 Designer bead
    └── my-factory-impl456 (closed)                     # L3 Coder bead
```

---

## Next Steps

After L3, your factory can:
- Plan features (Planner)
- Make architectural decisions (Architect)
- Design implementations (Designer)
- Write code and tests (Coder)

In **L4**, you'll add Reviewer + DevOps agents to complete the pipeline. The Reviewer reads your committed implementation and the spec side-by-side, producing a review report at `review-reports/<slug>-review.md`. The DevOps agent takes a green review report and produces a release gate decision at `release-gates/<slug>-release.md`. After L4, you'll have a 6-agent pipeline capable of taking a feature request all the way to a ready-to-deploy state without a human touching code.

The pattern is identical to what you just did twice (L2, L3): read pack, install pack, customize prompt, create bead, sling, review, iterate config, commit. You've now done the loop four times (planner, architect, designer, coder). L4 is two more passes on the same loop.
