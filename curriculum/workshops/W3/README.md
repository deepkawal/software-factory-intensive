# W3 · Architect Multi-Agent Coordination

> **Goal:** Understand how the six-agent pipeline coordinates in Gas City — which agent wakes when, how a finished stage hands off to the next, where human review belongs — and write a one-page coordination map for your project you can execute in L4 and the capstone.

| | |
|---|---|
| **Estimated duration** | ~45 minutes |
| **Type** | WORKSHOP |
| **Deliverable** | `coordination-map.md` + gate justification notes committed at `activities/workshops/W3/` |

---

## Session workspace note

W3 is a design session — no pack is installed and `my-factory/city.toml` is not touched. The coordination map + gate docs live at `../../../activities/workshops/W3/`. You'll exercise the design in L4 and C1 using the shipped packs under `packs/`.

---

## Architecture Diagram

```
  Feature Request (bead, --labels needs-plan)
        │
        ▼
  ┌───────────┐   work-packages/<slug>.md   ┌───────────┐
  │ PLANNER   │ ──────────────────────────► │ ARCHITECT │
  │ wakes on  │                             │ wakes on  │
  │ needs-plan│   ◂── handoff: operator ──► │ needs-    │
  └───────────┘       files fresh bead       │ architect │
                      with next label        └─────┬─────┘
                                                   │  docs/adr/NNNN-<slug>.md
                                                   ▼
  ┌───────────┐   design/<slug>.md         ┌───────────┐
  │ DESIGNER  │ ◄───────────────────────── │ (operator │
  │ wakes on  │                            │  reviews, │
  │ needs-    │ ──────────────────────────►│  files    │
  │ design    │                            │  next)    │
  └─────┬─────┘                            └───────────┘
        │  design/<slug>.md
        ▼
  ┌───────────┐   src/**/*.ts + tests      ┌───────────┐
  │ BUILDER   │ ──────────────────────────► │ REVIEWER  │
  │ wakes on  │   (feature branch commit)   │ wakes on  │
  │ ready-to- │                             │ needs-    │
  │ build     │   ◂── operator reviews ───► │ review    │
  └───────────┘      builder's work         └─────┬─────┘
                                                  │  review-reports/<slug>.md
                                                  ▼
                                            ┌───────────┐
                                            │ RELEASE-  │
                                            │ GATE      │   [HUMAN GATE]
                                            │ wakes on  │   approve before
                                            │ ready-to- │   production deploy
                                            │ ship      │
                                            └─────┬─────┘
                                                  │ release-gates/<slug>.md
                                                  ▼
                                            Production
```

**Arrows carry beads.** Beads carry labels and metadata. Each agent's order gate watches for a label; when a bead appears with the matching label, the agent wakes. No central orchestrator exists — the flow is emergent from labels, decided by whoever files the next bead.

---

## Prerequisites

| Prerequisite | How to verify | If it's missing |
|---|---|---|
| L2 complete | `gc status` shows `your-repo/planner.planner` and `your-repo/architect.architect` | Complete L2 |
| One closed work package + ADR in your rig | `ls work-packages/ docs/adr/` shows at least one file in each | L2 produces both |
| PROJECT_MANIFEST.md is tight | Review Standards + Release Criteria sections exist and have testable rules | Tighten before starting — vague manifests produce vague coordination |

---

## Gas City's Coordination Primitives

There are three, and only three:

### Primitive 1: Labels on Beads

A bead is a unit of work. Its `--labels` field is what agents match against. The six pipeline stage labels are:

| Stage label | Which agent wakes on it |
|---|---|
| `needs-plan` | `planner` |
| `needs-architecture` | `architect` |
| `needs-design` | `designer` |
| `ready-to-build` | `builder` |
| `needs-review` | `reviewer` |
| `ready-to-ship` | `release-gate` |

When you `bd create --title "..." --labels <stage-label>`, you're queuing work for that stage.

### Primitive 2: Order Gates on Agents

Each agent pack ships an **order** in `packs/<agent>/orders/` that defines the agent's wake query. It's a declarative filter: "wake this agent when a bead exists with a matching label, is not already assigned, and is routed to me."

The wake query runs every reconciler tick. When it matches a bead, the reconciler spawns a session for that agent and the agent starts processing.

You don't write order gates in W3 — the shipped packs include them. Read one to see the shape:

- [`packs/planner/orders/`](../../../packs/planner/orders/) — the Planner's wake condition
- [`packs/architect/orders/`](../../../packs/architect/orders/) — same, for the Architect
- ...and so on for the other four agents

### Primitive 3: Handoff via a Fresh Bead

Handoff is **not** automatic. When an agent finishes its artifact and closes its bead, nothing pulls the next stage forward. The operator (or a formula, if you wire one) decides to file the next stage's bead.

The shape is always:

```bash
bd create --title "<stage>: <feature>" --labels <stage-label> --description "..."
gc sling --nudge your-rig/<agent>.<agent> <new-bead-id>
```

Each pipeline stage gets its own new bead. Beads are never re-slung — a stuck stage means filing a new bead with the current label, not redirecting an existing one.

---

## Coordination Concept 1: Sequential Chaining

**When:** Stage B cannot start until Stage A's artifact is in place, because Stage B reads it.

**Shape:** File Stage B's bead with Stage B's label *after* Stage A's artifact lands on disk.

**Example (Fired Up Pizza loyalty points):**

```
Planner writes work-packages/loyalty-points-system.md
         ↓  (operator reviews the work package)
Architect writes docs/adr/0001-loyalty-points-storage.md
         ↓  (operator reviews the ADR)
Designer writes design/loyalty-points-spec.md
         ↓  (operator reviews the spec)
Builder writes src/loyalty/* + tests on feature/loyalty-points
```

**Commands:**

```bash
# Kickoff
bd create --title "Feature: Loyalty Points" --labels needs-plan --description "..."
gc sling --nudge your-rig/planner.planner <root-bead-id>

# After work-packages/loyalty-points-system.md appears:
bd create --title "Architecture: Loyalty Points Storage" --labels needs-architecture --description "..."
gc sling --nudge your-rig/architect.architect <architect-bead-id>

# ...and so on for each stage
```

**Use sequential chaining when:** the downstream agent's prompt lists the upstream artifact as an input.

**Don't use sequential chaining when:** two stages can proceed in parallel because neither reads the other's artifact. In W3 you intentionally keep the pipeline linear; parallel fan-out is a C1 refinement, not a W3 design.

> **Inline insight.** The linear pipeline is the honest default. Every parallel fan-out adds a join point, and every join point is a place where state can desync between agents. Start linear. Add parallelism only once you have a working linear pipeline and a specific bottleneck you've observed.

---

## Coordination Concept 2: Human Gates

**When:** The next stage has consequences that are hard or impossible to reverse, and no amount of agent improvement makes the decision safe to automate.

**Shape:** Don't file the next stage's bead until a human has reviewed the upstream artifact and is ready to proceed. There is no `--requires-approval` mechanic in v2 — the gate is simply "the operator stops, reads, and decides."

**Example:** Between Reviewer and Release-Gate, a human reviews the review report and confirms the migration plan is safe before filing the `ready-to-ship` bead. If the review report says `REQUEST-CHANGES`, the operator loops back to the Builder instead of slinging the Release-Gate.

**The "while I was asleep" test.** For every pause point you're considering making a gate, ask: if this ran unattended at 3 AM and produced wrong output, what happens? If the answer is "caught in a later stage and easy to redo," it's not a gate — just let it run. If the answer is "data loss / production outage / user-visible breakage," it's a gate.

**Gate placement decision tree (Fired Up Pizza example):**

| Transition | Worst-case if unattended | Gate needed? |
|---|---|---|
| Planner → Architect | Bad work package → bad ADR, caught by Architect | No |
| Architect → Designer | Bad ADR → bad spec, caught by Designer | No |
| Designer → Builder | Bad spec → bad code, caught by Reviewer | No |
| Builder → Reviewer | Bad code → caught by Reviewer's verdict | No |
| Reviewer → Release-Gate | Review says APPROVE when it shouldn't → production bug | **Yes** |
| Release-Gate → Production | Unreviewed migration corrupts customer data | **Yes** (the gate is "don't run the actual deploy until a human approves") |

Two gates max is a healthy factory. Five is a factory that isn't running.

---

## Coordination Concept 3: Artifact Flow

Agents don't pass data to each other through memory or any coordination bus. They pass it through **files on disk, committed to the rig**. The Architect reads the Planner's work package file; the Designer reads both the work package and the ADR; and so on.

This means every handoff has a literal filesystem path. If a downstream agent says it can't find the upstream artifact, the path is wrong — check the upstream prompt's Output Format section.

**The shipped pipeline's artifact map:**

| Stage | Agent writes | Path (relative to rig) |
|---|---|---|
| Plan | Planner | `work-packages/<slug>.md` |
| Architecture | Architect | `docs/adr/NNNN-<slug>.md` |
| Design | Designer | `docs/design/<slug>.md` |
| Build | Builder | `src/**/*.ts` + tests on `feature/<slug>` branch |
| Review | Reviewer | `review-reports/<slug>-review.md` |
| Release | Release-Gate | `release-gates/<slug>-gate.md` |

If your project's layout differs (e.g., Python project, different `src/` convention), customise the agent prompts (the copy-and-override pattern from L2/L3/L4) to write to your project's paths.

---

## Workshop Activity — Write Your Coordination Map

You're going to write a single markdown file that captures these decisions for your project. The file is named `coordination-map.md` and lives in `activities/workshops/W3/`.

### Step 1: Create the File

```bash
cd activities/workshops/W3
touch coordination-map.md
```

### Step 2: Write the Stage Table

Copy this template into `coordination-map.md` and fill in the `Agent reads / Agent writes / Trigger / Gate?` columns for your project:

```markdown
# Coordination Map — <Your Project>

## Feature: <name>

| # | Stage | Agent | Trigger | Agent reads | Agent writes | Gate? |
|---|-------|-------|---------|-------------|--------------|-------|
| 1 | Plan | planner | `bd create --labels needs-plan` | bead description, `docs/PROJECT_MANIFEST.md` | `work-packages/<slug>.md` | No |
| 2 | Architecture | architect | `bd create --labels needs-architecture` (after Plan artifact lands) | work package, `CLAUDE.md`, existing ADRs | `docs/adr/NNNN-<slug>.md` | No |
| 3 | Design | designer | `bd create --labels needs-design` | work package, ADR, manifest | `docs/design/<slug>.md` | No |
| 4 | Build | builder | `bd create --labels ready-to-build` | design spec, ADR, work package | `src/**` on `feature/<slug>` | No |
| 5 | Review | reviewer | `bd create --labels needs-review` | code diff, spec, work package, Review Standards | `review-reports/<slug>-review.md` | No |
| 6 | Release | release-gate | `bd create --labels ready-to-ship` (after human reviews report) | review report, Release Criteria | `release-gates/<slug>-gate.md` | **Yes** |
```

Customise the `reads` and `writes` columns for your project's layout. The `Trigger` column is always the same shape (`bd create --labels <stage-label>`).

### Step 3: Add Human Gate Notes

For every row with `Gate? = Yes`, write a short justification section below the table:

```markdown
## Gates

### Gate: approve release

**Between:** Review and Release.

**Risk being mitigated:** <one sentence — what goes wrong if this runs unattended?>

**Evidence the gate is necessary:** <what specifically can't be verified by the Reviewer that a human can verify?>

**Removal condition:** <under what future conditions would you drop this gate?>

**Approver:** <your email>
```

Every gate without a removal condition becomes permanent infrastructure nobody trusts. Writing the removal condition up front is the discipline that keeps the gate honest.

### Step 4: Add the Artifact Chain

Below the gate notes, write a short section listing exactly which upstream artifacts each downstream stage reads. This is the document you'll consult in L4 and C1 when something doesn't flow.

```markdown
## Artifact Chain

- Architect reads: work package from Plan stage + `CLAUDE.md` + existing ADRs in `docs/adr/`
- Designer reads: work package + ADR from Architecture stage + `docs/PROJECT_MANIFEST.md`
- Builder reads: design spec + ADR + work package + manifest
- Reviewer reads: git diff on feature branch + design spec + work package + Review Standards section of manifest
- Release-Gate reads: review report + Release Criteria section of manifest
```

Every arrow is a real file path. If an agent's prompt doesn't list a path here as an input, the handoff is broken — fix the prompt, not this map.

### Step 5: Commit

```bash
git add activities/workshops/W3/coordination-map.md
git commit -m "docs(w3): coordination map for <feature>"
```

The map is the source of truth for coordination. In L4 you'll run the pipeline stage-by-stage; at each stage you'll verify the map still matches reality. Drift between map and reality is a signal to update one or the other before proceeding.

---

## Workshop Activity — Self-Review

Before you ship, answer these questions in `activities/workshops/W3/notes.md`:

### Question 1: Can any stage start before its upstream artifact exists?

For each stage row in your map, confirm that the `Agent reads` column lists files that the `Agent writes` column of some upstream row produces. If a downstream stage reads a file that no upstream stage writes, your map is broken.

### Question 2: Is every human gate justified?

Apply the "while I was asleep" test to each gate. If two of your gates fail the test, they're theatrical — cut them.

### Question 3: What happens if a stage crashes mid-run?

The Gas City v2 model has no built-in retry. If the Planner session dies halfway through writing the work package, you close the broken bead and file a fresh `needs-plan` bead. Note in your map which stages are most prone to this (typically the long-running ones — Builder, Reviewer) so future-you knows where to watch.

---

## Common Issues & Solutions

| Issue | Symptom | Fix |
|---|---|---|
| **Downstream agent doesn't wake after you sling** | `gc session list` shows nothing; bead has the label but no session spawns | Check `bd show <bead>` for `metadata.gc.routed_to` — it should match the target. If missing, re-sling with `gc sling --nudge --force <target> <bead>`. |
| **Stage B runs before Stage A's artifact lands** | Agent B's session starts but immediately errors "cannot find <upstream file>" | You filed Stage B's bead too early. Close the Stage B bead, wait for Stage A's artifact, file a fresh Stage B bead. |
| **Downstream agent reads a file the upstream agent didn't produce** | Agent B's session hallucinates the upstream file's contents | The upstream agent's Output Format doesn't require that file. Update the upstream prompt to require the path literally. |
| **Gate approver is a single person** | Pipeline blocks indefinitely when you're on vacation | Document a fallback approver in the gate justification. |
| **Gate justification is empty / "just to be safe"** | Six months later, the gate gets approved reflexively | Write the removal condition before adding the gate. No removal condition = no gate. |
| **Too many human gates** | Factory can't run autonomously overnight | Apply the "while I was asleep" test. Cut every gate that doesn't answer "unacceptable" to the worst case. Aim for one gate, max two. |
| **Stage artifacts drift from your coordination map** | Agents write to different paths than the map says | Update the agent prompt to match the map, or update the map to match reality. Don't let them diverge silently. |

---

## Connection to Gas City

The coordination map compiles to two things:

1. **Labels on beads.** Every row's `Trigger` column is a `bd create --labels <stage-label>` invocation.
2. **Agent order gates.** Already shipped in `packs/<agent>/orders/` — you don't write these, you just trust them to fire when a matching-labelled bead appears.

**Where to look in the repo:**

- [`packs/planner/orders/`](../../../packs/planner/orders/), [`packs/architect/orders/`](../../../packs/architect/orders/), [`packs/designer/orders/`](../../../packs/designer/orders/), [`packs/builder/orders/`](../../../packs/builder/orders/), [`packs/reviewer/orders/`](../../../packs/reviewer/orders/), [`packs/release-gate/orders/`](../../../packs/release-gate/orders/) — one order per agent, each defining the wake condition.
- [`packs/all/pack.toml`](../../../packs/all/pack.toml) — the composition pack that imports every leaf pack and exposes `gc all wake-downstream` for the case where you want to poke every candidate agent simultaneously.

**Config discipline extends to coordination.** L1 taught you to update `CLAUDE.md` instead of re-prompting. L2 taught you to update the pack's prompt file instead of editing the agent's artifact. W3's rule is the same shape: **if the factory's coordination is wrong, update the agent prompt or the manifest's Review Standards / Release Criteria, and re-file the bead. Never hand-edit bead states or work around the labels.**

---

## Exit Criteria

- [ ] `activities/workshops/W3/coordination-map.md` committed with all 6 stages filled in
- [ ] At least one gate justification written with the Risk / Evidence / Removal-Condition shape
- [ ] `activities/workshops/W3/notes.md` answers the three self-review questions
- [ ] Every stage's `Agent reads` column references only files that some upstream stage `writes` (or pre-existing files like `CLAUDE.md`, `docs/PROJECT_MANIFEST.md`)

**W3 blocks L4.** L4 is where you run the full pipeline against a real feature and verify your coordination map describes what actually happens. Without a committed map, L4's debugging ("what should have happened at this step?") has no anchor.

---

## Next Steps

In **L4**, you'll:

- Run the full six-agent pipeline against a feature, using the map you wrote here
- Exercise the human gate at `needs-review → ready-to-ship`, catching findings the Reviewer surfaces
- Fix findings via Builder-prompt edits (not manual code edits), re-filing fresh `ready-to-build` beads
- Observe where your map's stage-read-and-write columns match reality, and where they drift — update whichever side is wrong
