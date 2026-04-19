# L1 · Build a Structured Development Loop

> **Goal:** Install Gas City, add your project as a rig, convert your W1 workflow card into a working `CLAUDE.md`, and sling your first real bead to an agent. By the end, the agent implements a small feature and commits it without you typing into the chat.

| | |
|---|---|
| **Estimated duration** | ~60 minutes |
| **Type** | LAB |
| **Deliverable** | Working `CLAUDE.md` (or `AGENTS.md`) + committed feature + `DECISIONS.md` entry |

---

## Architecture Diagram

```
                    ┌───────────────────────────┐
                    │      User Story             │
                    │  (from your backlog)        │
                    └─────────────┬─────────────┘
                                  │
                                  ▼
                    ┌───────────────────────────┐
                    │          bd create          │
                    │  (a bead in Gas City)       │
                    └─────────────┬─────────────┘
                                  │
                                  ▼
                    ┌───────────────────────────┐
                    │  gc sling --nudge           │
                    │  your-project/claude        │
                    │       <bead-id>             │
                    └─────────────┬─────────────┘
                                  │
                                  ▼
                    ┌───────────────────────────┐
                    │       CLAUDE AGENT          │
                    │  (implicit, built into gc)  │
                    │                             │
                    │  Reads:                     │
                    │    • bead description       │
                    │    • CLAUDE.md              │
                    │    • docs/PROJECT_MANIFEST  │
                    │                             │
                    │  Produces:                  │
                    │    • implementation in src/ │
                    │    • tests                  │
                    │    • a conventional commit  │
                    └─────────────┬─────────────┘
                                  │
                                  ▼
                    ┌───────────────────────────┐
                    │      Quality Gates          │
                    │  (lint, type-check, test,   │
                    │        build)               │
                    └─────────────┬─────────────┘
                                  │
                            pass  │  fail
                                  │
                     ┌────────────┴────────────┐
                     ▼                         ▼
         ┌──────────────────┐       ┌──────────────────────┐
         │  git log shows    │       │  Edit CLAUDE.md,      │
         │  the commit —     │       │  git reset --hard,    │
         │  you didn't type  │       │  re-sling the bead    │
         │  a line of code   │       │  (the loop is config, │
         └─────────┬────────┘       │   NOT chat)            │
                   │                 └───────────┬──────────┘
                   ▼                             │
         ┌──────────────────┐                    │
         │  DECISIONS.md     │◄───────────────────┘
         │  logs what        │
         │  changed and why  │
         └──────────────────┘
```

**The Config Discipline:** When the agent produces wrong output, you update `CLAUDE.md` and re-sling the bead. You do **not** type a correction into chat. This is the single most-tested behavior of the lab — every iteration is a file diff, not a conversation.

---

## Prerequisites

Before starting this lab, verify each of these:

| Prerequisite | How to verify | How to fix |
|-------------|---------------|-----------|
| W1 complete | `ls ~/path/to/your-repo/workflow-card.md` → file exists | Go back and complete W1. L1 evolves your workflow card into agent instructions — without it, you're starting from scratch. |
| Gas City installed | `gc --version` → prints a version | `brew install gastownhall/gascity/gascity` |
| Claude Code installed | `claude --version` → prints a version | Install Claude Code from https://claude.ai/download and run `claude auth login`. Other providers (`codex`, `cursor`, `gemini`) also work — the `provider` field in `city.toml` selects one. |
| Project repo cloned | `cd ~/path/to/your-repo && git status` → clean or known state | `git clone <your-repo-url> ~/path/to/your-repo` |
| Project manifest | `cat ~/path/to/your-repo/docs/PROJECT_MANIFEST.md` → filled in | Copy from [`curriculum/PROJECT_MANIFEST_TEMPLATE.md`](../../PROJECT_MANIFEST_TEMPLATE.md) and fill in tech stack, conventions, domain model. You can defer this to Step 2 of this lab. |
| A small backlog item | A user story you could implement by hand in 15–30 minutes | If you don't have one, borrow from [`reference-project/fired-up-pizza/tickets.md`](../../../reference-project/fired-up-pizza/tickets.md) — we'll use FUP-3-style "Show Order Total in Cart" as the running example. |

---

## Running Example: Show Order Total in Cart

Throughout this lab, we use a single small feature as the running example: **"Show Order Total in Cart."** It's deliberately tiny — one component, a handful of files, no architectural questions — because your first sling is a calibration run, not a hero play. You're proving the loop works end-to-end, not building the killer feature.

If you're working against your own project, substitute something comparably small. The criteria: you could implement it by hand in under 30 minutes, it touches fewer than five files, and it doesn't require any architectural decision the agent couldn't reasonably make alone.

If you're working against Fired Up Pizza (the reference project), this maps closely to FUP-3 (Shopping cart) scoped down to "just the running total." Full FUP-3 would take longer than L1 budgets.

---

## Gas City Capabilities Used This Lab

| Command | What it does | Used in step |
|---------|--------------|--------------|
| `gc register .` | Register the pre-configured `my-factory/` workspace as a city | Step 1 |
| `gc rig add <path>` | Register a project repo as a "rig" — a place agents can work | Step 1 |
| `gc rig list` | Show all rigs registered with the city | Step 1 |
| `gc status` | Show all agents, their state, and last activity | Step 3, 7 |
| `gc doctor` | Validate tools, auth, and pack config | Step 2 (optional) |
| `gc restart` | Re-read `pack.toml` / `city.toml` and restart agents | Step 3 |
| `bd create --title ... --labels ...` | Create a work item ("bead") that agents can pick up | Step 6 |
| `bd list` | Show beads and their status | Step 6 |
| `bd show <bead>` | Show a single bead's full description and status | Step 7 |
| `gc sling --nudge <agent> <bead>` | Route a bead to an agent and wake the session | Step 7 |
| `gc session peek <id-or-alias>` | View the agent's current output without attaching | Step 7 |
| `gc session attach <id-or-alias>` | Attach to the running session (tmux) | Step 7 |
| `gc events --follow` | Stream city-wide event log | Step 7 |
| `bd close <bead>` | Mark a bead complete with a comment | Step 9 |

You will *not* install an agent pack in this lab — you'll use gc's built-in `claude` implicit agent, controlled entirely by `CLAUDE.md` in your rig. Agent packs arrive in L2.

---

## Reference: What Mature Looks Like

Before starting, skim the reference project:

- [`reference-project/fired-up-pizza/docs/PROJECT_MANIFEST.md`](../../../reference-project/fired-up-pizza/docs/PROJECT_MANIFEST.md) — the project manifest an agent reads *before every task*.

And the skeleton you'll start from:

- [`my-factory/PROJECT_MANIFEST.md`](../../../my-factory/PROJECT_MANIFEST.md) — the manifest template you'll fill in for your project.
- [`reference-project/fired-up-pizza/CLAUDE.md`](../../../reference-project/fired-up-pizza/CLAUDE.md) — a completed reference `CLAUDE.md`. Copy the structure, fill in your project's specifics, and save your version as `activities/labs/L1/CLAUDE.md` (or `AGENTS.md` for non-Claude assistants).

---

## Step 1: Initialize Your City and Register Your Rig (~10 min)

Your "city" is the workspace where all agents and beads live. Your "rig" is the project repo the agent will work in. A city can host many rigs; a rig is always a git repo.

### Step 1.1: Register Your Workspace

The repo already contains a ready-to-use workspace at `my-factory/`. You *register* that directory with the Gas City supervisor rather than running `gc init` from scratch — `gc init` would overwrite the pre-configured `city.toml`.

```bash
# From the repo root
cd my-factory
gc register .
```

Expected output (truncated):

```
Registered city 'my-factory' (/Users/you/.../software-factory-intensive/my-factory)
Installed launchd service: /Users/you/Library/LaunchAgents/com.gascity.supervisor.plist
  Adopting sessions...
  Starting agents...
```

**What's happening here:** `gc register` tells the long-running Gas City supervisor that this directory is a city it should manage. The shipped `my-factory/city.toml` is used as-is (no pack includes yet — those come in L2). The supervisor keeps agents alive between terminal sessions. You can inspect and edit `my-factory/city.toml` directly.


### Step 1.2: Register Your Project Repo as a Rig

```bash
# Register your project repo. Paths are resolved relative to my-factory/.
cd my-factory
gc rig add ../../path/to/your-repo
```

Expected output:

```
Re-initializing rig 'your-repo'...
  Detected git repo at /Users/you/path/to/your-repo
  Prefix: yr
  Initialized beads database
  Generated routes.jsonl for cross-rig routing
Rig re-initialized.
```

**What's happening here:** The rig registration does three things: it records the rig's path in `city.toml`, it initializes a per-rig beads database so work items in this rig have stable IDs, and it generates routing metadata so agents in one rig can refer to artifacts in another. The two-letter `Prefix` (`yr` here) is how bead IDs are namespaced — you'll see bead IDs like `yr-abc` shortly.

### Step 1.3: Verify the Rig Is Registered

```bash
# Verify it's registered.
gc rig list
```

Expected output:

```
Rigs in /Users/you/my-city:
  my-city (HQ):
    Prefix: mc
    Beads:  initialized
  your-repo:
    Path:   /Users/you/path/to/your-repo
    Prefix: yr
    Beads:  initialized
```

**What's happening here:** Every city has an HQ rig (the city itself) plus any rigs you've added. `my-city (HQ)` is the meta-rig where cross-rig orchestration beads can live; `your-repo` is the code rig where the agent will actually work. The `dir` field you're about to add to `city.toml` in Step 3 must match the name `your-repo` exactly — copy it from this output, don't retype it.

### Step 1.4 (Optional): Create the Agent-Output Directories in Your Rig

L2 through L4 expect a predictable directory layout inside your project rig for factory-generated artifacts. Create them now so the Planner doesn't fail on a missing `work-packages/` the first time you sling it.

```bash
cd ../../path/to/your-repo
mkdir -p work-packages docs/adr design review-reports release-gates feedback-loops
touch work-packages/.gitkeep docs/adr/.gitkeep design/.gitkeep \
      review-reports/.gitkeep release-gates/.gitkeep feedback-loops/.gitkeep
git add work-packages docs design review-reports release-gates feedback-loops
git commit -m "chore: bootstrap factory output directories"
```

**What's happening here:** Each agent writes to one of these directories. Creating them now (with `.gitkeep` sentinels) means you don't scramble in L2–L4. None are used in L1 itself.

Your `CLAUDE.md` goes at your project repo's root — you'll draft it in Step 4. Keep a copy at `activities/labs/L1/CLAUDE.md` too so the session has a self-contained deliverable record.

---

## Step 2: (Optional) Connect External Services via the Workshop Pack (~10 min)

If your project uses Jira, Linear, GitHub Issues, GitLab, Sentry, DataDog, etc., install the `packs/workshop/` integrations pack now. Skipping this is fine — you can wire integrations in later. The first sling will work without any of them.

### Step 2.1: Attach the Workshop Pack to the Rig

Edit `my-factory/city.toml` and add a rig-scoped import to your `[[rigs]]` block:

```toml
[[rigs]]
name = "your-repo"
# ...existing fields generated by gc rig add...

[rigs.imports.workshop]
source = "../packs/workshop"
```

Then apply:

```bash
cd my-factory
gc restart
```

**What's happening here:** `[rigs.imports.workshop]` binds the `workshop` pack into this specific rig. The workshop pack brings service-integration scaffolding — it does not add agents (those come from `packs/planner`, `packs/architect`, etc. starting in L2).

> **Note:** `my-factory/city.toml.template` already contains `default_rig_includes = ["../packs/all"]`, which composes the pipeline agents shipped in `packs/all` into every rig. `workshop` is a separate pack for service integrations; adding it via `[rigs.imports.workshop]` layers it on top without disturbing `packs/all`.

### Step 2.2: Copy the Credential Template

```bash
# Copy the credential template into the repo and fill it in
cp /path/to/software-factory-intensive/packs/workshop/env.example ~/path/to/your-repo/.env
# Edit .env — only fill in the services you actually use
```

**What's happening here:** `.env` is gitignored. Each integration (Jira, Linear, Sentry, etc.) activates only if its env vars are present. Leaving vars blank means that integration is silently skipped — no error, no warning.

### Step 2.3: Validate the Setup

```bash
# Validate the setup
gc doctor
```

Expected `gc doctor` output (truncated):

```
  ✓ city-structure — city.toml present
  ✓ city-config — city.toml loaded
  ✓ config-valid — agents, rigs, and services valid
  ✓ config-refs — all config references valid
  ✓ tmux-binary — found /opt/homebrew/bin/tmux
  ✓ git-binary — found /usr/bin/git
  ✓ jq-binary — found /usr/bin/jq
  ✓ rig:your-repo:path — path "/Users/you/path/to/your-repo" exists
  ✓ rig:your-repo:git — git repository
  ✓ rig:your-repo:beads — store accessible
  ✓ bd:check-bd — bd available
  ✓ dolt:check-dolt — dolt available
```

**What's happening here:** `gc doctor` walks every check in every pack and reports pass/fail. Only the core tool checks are required. Warnings for optional integrations (Jira, Linear, etc.) are expected — each activates only if you filled in the matching env vars. If core tool checks fail, fix those first; optional checks you can leave broken if you're not using that integration.

What the pack unlocks once configured:

- Periodic sync orders (every 5 minutes) from your issue tracker into beads — see `packs/workshop/orders/sync-*/`
- MCP server tool access for observability (Sentry, DataDog, PostHog, Grafana) so agents can query errors and dashboards directly
- Cloud CLI validation (`aws`, `gcloud`, `az`) for future deploys

The full map of what the pack configures is in [`packs/workshop/README.md`](../../../packs/workshop/README.md).

---

## Step 3: Verify Your `claude` Agent Is Ready (~5 min)

Gas City ships a built-in **`claude` agent** available in every rig. It reads `CLAUDE.md` from the rig's root as its behavior file, which is exactly what L1 needs.

### Step 3.1: Confirm the `claude` Agent Is Available

```bash
cd my-factory
gc restart
gc status
```

Expected output (truncated):

```
my-factory  /Users/you/.../my-factory
  Controller: standalone (PID <pid>)
  Suspended:  no

Agents:
  claude                  pool (min=0, max=unlimited)
  your-repo/claude        pool (min=0, max=unlimited)

Rigs:
  your-repo  /Users/you/path/to/your-repo
```

**What's happening here:** `gc restart` tells the supervisor to re-read `pack.toml` and `city.toml` and bring the city to its declared state. `gc status` shows the result. The two `claude` entries are both the built-in agent — the city-scoped one (`claude`) for city-wide work, and the rig-scoped one (`your-repo/claude`) that opens your project repo's working directory. You'll use the rig-scoped form throughout the lab because the feature lives in your project repo, not the city.

### Step 3.2: (Optional) Choose a Different Provider

If you want `codex`, `gemini`, or another provider instead of Claude, edit `my-factory/city.toml` and set the workspace provider:

```toml
[workspace]
provider = "codex"
```

Then `gc restart`. Each supported provider has its own built-in agent (`codex`, `gemini`, etc.), and gc's agent resolution will route your slings to the matching provider's session. The rest of this lab uses Claude; if you pick a different provider, read `AGENTS.md` for `CLAUDE.md` throughout.

### Step 3.3: How the `claude` Agent Finds Its Instructions

The built-in `claude` agent has no prompt file of its own. When you sling a bead to it, it opens a Claude Code session in your rig's working directory. Claude Code then looks for `CLAUDE.md` in that directory on startup and loads it as part of its system prompt. So the agent's entire personality comes from the `CLAUDE.md` you're about to write in Step 4 — single-source-of-truth, editable via a diff.

### Step 3.4: When You'd Customise the Agent

Later labs ship custom agents as **packs** — directories containing `agents/<name>/agent.toml` (per-agent config) and `agents/<name>/prompt.template.md` (system prompt). A pack that defines `agents/claude/` overrides the built-in `claude` agent for the rigs that import that pack.

The shape you'll see in L2 looks like:

```
packs/planner/
└── agents/
    └── planner/
        ├── agent.toml        # scope, idle_timeout, wake behavior, etc.
        └── prompt.template.md
```

For L1, you don't need any of that — the built-in `claude` reading your `CLAUDE.md` is the complete single-agent loop.

---

## Step 4: Write Your `CLAUDE.md` (~15 min)

This is the step that matters most. `CLAUDE.md` is the agent's entire personality — everything it knows about your project's conventions, iteration style, and quality bar lives here. Every edit you make between slings is an edit to this file.

### Step 4.1: Copy the Skeleton

In **your project repo** (not the city), open `CLAUDE.md`. If you copied in the `my-factory/CLAUDE.md` skeleton in Step 1.4, edit it in place. Otherwise, create a new file at the repo root with the skeleton below.

(If you're using a non-Claude AI assistant — Codex CLI, Cursor, Gemini — name the file `AGENTS.md` instead. The structure is identical; most assistants look for either name.)

```markdown
# <Project Name> — Agent Instructions

## Project Context
- **Manifest**: `docs/PROJECT_MANIFEST.md` — read before every task.
- **Conventions**: <fill in — e.g. TypeScript strict, conventional commits, feature branches>

## Role
<one paragraph — what this agent is>

## Iteration Rule
<numbered list — your W1 Iteration Loop adapted for a single agent>

## Quality Gates
<numbered list — the commands that decide a commit is safe>

## Decision Log
<one paragraph — where you log rule changes>

## Output Format
<bullets — what commits, PRs, comments look like>
```

**What's happening here:** This skeleton mirrors the four sections of your W1 workflow card (Prompt Template, Context Reset Rule, Iteration Loop, Decision Checkpoint), but adapted for a standalone agent. The agent reads this file on every session — every rule here is enforced every time. Sections not present here (like a Role) are added because an agent needs the framing a human gets implicitly from team context.

### Step 4.2: Fill In the Role Section

```markdown
## Role
You are a feature implementation agent. Take a user story from a bead,
implement it end-to-end, and commit with a conventional message.
```

**What's happening here:** The Role is the agent's job description. Keep it narrow — "feature implementation" not "software engineer." A narrow role means the agent has fewer opportunities to creatively reinterpret what you asked for. In L2, each specialized agent will have an even narrower Role ("break feature requests into structured work packages").

### Step 4.3: Fill In the Iteration Rule Section

This is your W1 Iteration Loop, with one crucial change: it's now written *for the agent*, not for you.

```markdown
## Iteration Rule
1. Read the bead's description completely. Re-read linked files.
2. Write a 3-line plan. Confirm the plan by committing it to the bead
   as a comment before writing code.
3. Implement in small slices (one test-passable unit at a time).
4. Run quality gates after every slice. If a gate fails, stop and read
   the error before touching code.
5. Commit when gates pass; move to next slice.
```

**What's happening here:** Every step is an imperative ("Read", "Write", "Implement", "Run"). The agent follows imperatives reliably; it treats "prefer" or "consider" as advisory and skips them. Step 2 (the 3-line plan committed to the bead) is the single highest-leverage rule in the file — it forces the agent to externalize its reasoning before writing code, which catches 80% of misunderstandings before they become commits.

### Step 4.4: Fill In the Quality Gates Section

These are the commands the agent must run before every commit. Lift them verbatim from your project's CI config or package.json scripts — whatever your team already runs.

```markdown
## Quality Gates
Every commit must satisfy:
1. **Lint:** `npm run lint` — zero errors, zero warnings
2. **Tests:** `npm test` — all green, new tests for new code
3. **Types:** `npm run type-check` (or `tsc --noEmit`) — clean
4. **Build:** `npm run build` — succeeds
```

**What's happening here:** Quality Gates are the agent's exit criteria. They must be binary (pass/fail), deterministic (same result every run), and automatable (one shell command). "Code looks clean" is not a quality gate — `npm run lint` is. If your project uses different commands (pytest, go test, cargo build, make test), substitute them here. The agent will literally run these commands, parse their exit codes, and decide whether to commit.

### Step 4.5: Fill In the Decision Log Section

```markdown
## Decision Log
When you iterate on CLAUDE.md to fix an issue, add an entry to
`DECISIONS.md`. Include: date, the bead, what rule you added, why.
```

**What's happening here:** The agent doesn't usually edit `CLAUDE.md` itself — you do, between slings. But naming `DECISIONS.md` here means the agent reads that file too, and sees what rule changes you've made and why. Over time, that context helps the agent understand your project's grain.

### Step 4.6: Fill In the Output Format Section

```markdown
## Output Format
- Commits: `type(scope): description`
- PR descriptions: problem, solution, testing notes
- Comments explain WHY, not WHAT
```

**What's happening here:** Conventional commits are specified as `type(scope): description` so every commit is machine-parseable and easy to scan with `git log --oneline`. PR descriptions have a fixed structure so reviewers don't have to hunt. Code comments that explain WHY (not WHAT) are the only ones that survive a refactor — comments that restate the code are noise.

### Step 4.7: Commit on a Branch

```bash
cd ~/path/to/your-repo
git checkout -b claude-md-setup
git add CLAUDE.md
git commit -m "chore: add CLAUDE.md for claude agent (L1)"
```

**What's happening here:** Committing `CLAUDE.md` on a branch (not main) means your first sling runs against a known agent configuration — one you can roll back if it turns out to be wrong. Treating the agent config as a PR-worthy artifact is the same discipline you applied to `workflow-card.md` in W1.

---

## Inline Insight: Why `CLAUDE.md` Is the Only Thing You Edit

There are many places you could theoretically "correct" an agent: the bead description, a chat message, the Iteration Rule, the Quality Gate, a pack prompt file. Only one of those places persists.

- **Chat corrections** die with the session. Your next `gc sling` starts fresh and has never heard of your correction.
- **Bead description edits** persist, but only for that one bead. The next bead starts over.
- **`CLAUDE.md` edits** persist across every future session, every bead, every agent (for now — in L2 they become pack-specific, but the discipline is the same).

So the rule is: *if you find yourself about to type a correction, it probably belongs in `CLAUDE.md`.* That's the config-discipline mindset in one sentence.

The only exception is per-bead context — "implement this specific feature, not some other feature." That belongs in the bead description, which we'll write in Step 6.

---

## Step 5: Pick a Small Test Story (~5 min)

Choose one story from your backlog that you could manually code in 15–30 minutes. Smaller is better — your first sling is a calibration run, not a hero play. You want the feedback loop short so you can iterate on `CLAUDE.md` multiple times before running out of time.

If you don't have a backlog yet, borrow from Fired Up Pizza's tickets file:

- [`reference-project/fired-up-pizza/tickets.md`](../../../reference-project/fired-up-pizza/tickets.md) — e.g. "FUP-1: Menu display page" or "FUP-3: Shopping cart"

For the running example, we scope FUP-3 down to just the running total:

```markdown
# User Story: Show Order Total in Cart

**As a** customer
**I want** to see the total price in my cart
**So that** I know what I'll pay before checkout

## Acceptance Criteria
- [ ] Total updates on every quantity change
- [ ] Total formatted as currency with two decimals
- [ ] Total is 0.00 when cart is empty

## Technical Notes
- Use existing cart state in src/state/cart.ts
- Match existing currency util in src/utils/format.ts
```

**What's happening here:** The story has three acceptance criteria and two named existing files. The ACs are testable (every one can become a unit test). The Technical Notes name existing patterns the agent should match, which prevents it from inventing a new currency utility or a new state store. Vague stories produce vague code — every bullet here is deliberately narrow.

---

## Inline Insight: Why the First Slice Fails Most Often

When participants do this lab, the most common outcome on Sling 1 is: *the agent writes code that passes lint and build, but misses one acceptance criterion.* Usually the one about the empty state, or the one about currency formatting edge cases.

This is not an agent failure. It's a `CLAUDE.md` failure. Your Iteration Rule probably says "read the bead description completely" but doesn't say "enumerate each acceptance criterion as a test case before writing code." The agent reads the AC, files it mentally under "the big picture," and forgets it when coding the happy path.

The fix is almost always to tighten step 1 of the Iteration Rule: "Read the bead's description completely. **List each acceptance criterion as a line in your plan. Write a test for each AC before writing implementation code.**" That one addition typically moves first-sling success from 30% to 70%.

You'll discover this yourself in Step 8. Don't front-run the fix — see the failure first, then fix the config.

---

## Step 6: Create a Bead for the Story (~5 min)

A bead is a work item in Gas City. It has a title, a markdown description, a status, and an optional dependency chain. The description is the first thing the agent reads when you sling the bead to it.

### Step 6.1: Create the Bead

```bash
cd ~/path/to/your-repo
bd create \
  --title "Implement: Show Order Total in Cart" \
  --labels ready-to-build \
  --description "$(cat <<'EOF'
# User Story: Show Order Total in Cart

**As a** customer
**I want** to see the total price in my cart
**So that** I know what I'll pay before checkout

## Acceptance Criteria
- [ ] Total updates on every quantity change
- [ ] Total formatted as currency with two decimals
- [ ] Total is 0.00 when cart is empty

## Technical Notes
- Use existing cart state in src/state/cart.ts
- Match existing currency util in src/utils/format.ts
EOF
)"
```

This returns a bead ID like `yr-abc`. **Note the ID** — you'll use it for the next several steps. The prefix is your rig's 2–3 letter code from `gc rig list` (e.g. `yr` for a rig named `your-repo`).

### Step 6.2: Verify the Bead

```bash
bd list
```

You should see:

```
○ yr-abc ● P2 Implement: Show Order Total in Cart
```

**What's happening here:** The `HEREDOC` syntax (`<<'EOF'`) lets you pass a multi-line markdown description without escaping newlines or quotes. The quoted `'EOF'` disables shell variable expansion inside the description, so `$VAR` stays literal. `○` means the bead is open. `--labels ready-to-build` tags the bead for agents whose work queue filters on that label (in L1 it's mostly annotation for your own records — you'll dispatch via `gc sling` directly).

### Step 6.3: Anatomy of a Bead Description

The description you just passed has five subtle properties worth naming:

- **Title line.** Starts with `# User Story:` so the agent knows what *kind* of artifact this is (not a bug report, not an ADR).
- **As-a / I want / So that.** A standard user story frame. The agent uses "So that" to infer what "good" looks like when two implementations both satisfy the literal ACs.
- **Checkbox ACs.** Markdown checkboxes (`- [ ]`) are a signal to the agent that each line should become a test case. Dashed bullets alone don't carry that signal.
- **Technical Notes naming existing files.** This is the highest-leverage field. "Use `src/state/cart.ts`" steers the agent away from inventing parallel state. Without this, the agent defaults to "add what makes sense" which often means a new file that duplicates existing code.
- **No implementation prescription.** You describe what the feature does, not how to build it. That's the agent's job. If you find yourself writing pseudocode in the description, you're not delegating — you're typing code with extra steps.

---

## Step 7: Sling the Bead and Watch (~15 min)

"Slinging" routes a bead to an agent and wakes the session. This is the moment the agent starts actually working.

### Step 7.1: Sling

```bash
gc sling --nudge your-project/claude yr-abc
```

(Substitute `your-project` with your actual rig name from `gc rig list`, and `yr-abc` with your bead's id.)

Expected output:

```
Auto-convoy yr-<convoy-id>
Slung yr-abc → your-project/claude
Session "your-project/claude" is asleep — poked controller for wake
Queued nudge for your-project/claude
```

**What's happening here:** `gc sling` sets the bead's routing metadata (`gc.routed_to = your-project/claude`), creates an auto-convoy to track the work, and tells the supervisor to wake the target agent. The `--nudge` flag also submits the prompt to the session once it's up — without it, the session can sit idle waiting for input that never arrived. Gas City starts a tmux session, launches Claude Code inside your rig's working directory, loads `CLAUDE.md` as the system prompt, and hands the bead's description as the task. The agent is now autonomous — it will read, plan, implement, run quality gates, and commit without any further input from you.

### Step 7.2: Watch the Agent Work

```bash
gc session peek your-project/claude
```

**What's happening here:** `gc session peek` shows a snapshot of the agent's current terminal output without attaching to the session. You should see the agent read `CLAUDE.md`, then `docs/PROJECT_MANIFEST.md`, then the bead description, then begin writing a plan. Peek is safe to run repeatedly — it doesn't send any input. To actually attach and watch output stream (and be able to type into the session — **don't**), use `gc session attach your-project/claude`. Press `Ctrl+b d` to detach from tmux without killing the session. **Do not type into the attach window.** Anything you type goes into the agent's chat context and violates config discipline.

### Step 7.3: Monitor From Another Terminal

In a second terminal, watch the event stream and status:

```bash
gc events --follow       # Everything happening city-wide
gc status                # Agent states
bd show yr-abc           # Bead progress
```

**What's happening here:** `gc events --follow` is a city-wide event log — every file the agent reads, every command it runs, every tool call. `gc status` shows agent state (`active` while working, `asleep` when idle). `bd show` shows the bead's description plus any comments the agent has posted (including, if your Iteration Rule works, the 3-line plan).

### Step 7.4: Wait for Completion

Wait until the bead status reaches closed (`✓`) in `bd show`, or the session disappears from `gc session list`. For the running example, this typically takes 3–8 minutes depending on project size and quality-gate time.

### Step 7.5: What You Should See in the Event Stream

A healthy first sling produces a characteristic sequence of events. In another terminal running `gc events --follow`, you should see roughly this arc:

1. **Session spawn** — the tmux session starts, the agent initializes.
2. **File reads** — `CLAUDE.md`, `docs/PROJECT_MANIFEST.md`, any files named in the bead's Technical Notes.
3. **Bead comment** — the 3-line plan (if your Iteration Rule made it), posted to the bead.
4. **Edit events** — new or modified files under `src/` (or wherever your project code lives).
5. **Tool calls** — `npm run lint`, `npm test`, `npm run build` (or your project's equivalents).
6. **Commit event** — `git commit` with a conventional-commit message.
7. **Session idle** — the agent exits its task loop and waits.

If the sequence skips steps 2, 3, or 5, you've found a gap in `CLAUDE.md`. Most common: step 5 (quality gates) is skipped because the Iteration Rule doesn't explicitly require it. You'll find yourself fixing that gap in Step 8.

---

## Step 8: Review Output and Iterate (~10 min)

When the agent finishes, you review its work and decide whether to ship or re-sling.

### Step 8.1: Inspect the Commit

```bash
cd ~/path/to/your-repo
git log -5 --oneline
git diff HEAD~1
```

**What's happening here:** `git log -5 --oneline` shows the last five commits — you're looking for the one the agent just made. `git diff HEAD~1` shows everything that changed. Skim the diff before running tests — sometimes the problem is obvious (wrong file, missing imports, inline styles) and you can skip to the re-sling without burning time on the gates.

### Step 8.2: Run the Quality Gates

Run your project's quality gates. These are whatever your project already uses to decide code is committable — lint, type check, tests, build, or some subset. Your `CLAUDE.md` names them explicitly in the Quality Gates section; run exactly those commands, in the same order.

**What's happening here:** You're verifying the agent actually ran the gates it claims to have run. A passing agent will have already run them; a lying or broken agent might have committed without running them. Running them yourself is cheap insurance.

### Step 8.3: If Gates Pass

Proceed to Step 9.

### Step 8.4: If Gates Fail or Output Is Wrong

**Do not type into chat. Do not fix the code manually.** Instead:

1. **Identify the missing rule.** Be specific: "The agent used inline styles — that's not forbidden in `CLAUDE.md`." "The agent skipped tests — the Quality Gates section doesn't require them explicitly enough." "The agent forgot the empty-cart AC — the Iteration Rule doesn't enumerate ACs as tests."
2. **Edit `CLAUDE.md`** to add the missing rule in exact, testable terms. Imperatives only: "NEVER X" or "Before Y, do Z."
3. **Reset the branch:** `git reset --hard HEAD~1`
4. **File a fresh bead and re-sling.** Beads in Gas City aren't re-slung — each iteration creates a new bead so the downstream routing metadata stays clean:
   ```bash
   bd create --title "Implement: Show Order Total in Cart (v2)" --labels ready-to-build --description "$(cat <<'EOF'
   <paste the same user story, unchanged>
   EOF
   )"
   gc sling --nudge your-project/claude <new-bead-id>
   ```
5. **Log the iteration** in `DECISIONS.md` (see Step 9).

**What's happening here:** Each re-sling runs against a *new* `CLAUDE.md`, which means it's a new, cleaner agent configuration. `git reset --hard HEAD~1` wipes the agent's previous attempt so the re-slung agent starts from the same state it started from the first time. If you don't reset, the second sling has to figure out what to do with the first sling's half-finished work, which confuses it.

**Target:** ≤3 slings to passing. If you hit 3 and still failing, your `CLAUDE.md` is probably fighting your project's existing conventions — pause, re-read the conflicting rule alongside an example of the convention in your repo, and rewrite.

---

## Step 9: Write Your `DECISIONS.md` Entry (~5 min)

`DECISIONS.md` is the log of what you changed in `CLAUDE.md` and why. Future you (and future teammates) will thank present you for writing this.

### Step 9.1: Create or Append to `DECISIONS.md`

```markdown
# Decisions

## 2026-04-21 · yr-abc, yr-def, yr-ghi · Show Order Total in Cart

### Context
First L1 sling. Implicit `claude` agent with baseline CLAUDE.md.

### What Happened
- Sling 1 (yr-abc): agent forgot to run quality gates before committing
- Sling 2 (yr-def): agent used inline styles in the cart component
- Sling 3 (yr-ghi): passed all gates, committed cleanly

### CLAUDE.md Changes
- Added explicit "Run all Quality Gates before every commit. If any fails, stop." to Iteration Rule step 4.
- Added "No inline styles — use Tailwind classes or CSS modules" to Project Context.

### Lessons
- The agent treats CLAUDE.md as law, but only for rules written as imperatives. "Prefer X" is ignored. "NEVER X" is followed.
- Re-slinging after `git reset --hard` is cheap — don't be afraid to iterate.
```

**What's happening here:** The structure is deliberate: Context (what was the situation), What Happened (sling-by-sling trace), CLAUDE.md Changes (the exact diff), Lessons (what you learned about your project and the agent). The Lessons section is the most valuable part — it's what survives beyond the specific bead and informs every future agent config.

### Step 9.2: Commit Everything

```bash
git add CLAUDE.md DECISIONS.md
git commit -m "docs: update agent rules after first sling (L1)"
git push -u origin claude-md-setup
```

### Step 9.3: Close the Bead

```bash
bd close yr-ghi --note "Feature shipped. CLAUDE.md updated with 2 new rules."
```

(Use the id of the bead that actually produced the shipping commit.)

**What's happening here:** Closing the bead with a descriptive note leaves a breadcrumb. When you (or an orchestrator agent in the capstone) later look at bead history, the note tells you what actually shipped, not just that something did. The earlier beads (from re-slings) should also be closed with notes explaining what the rule-gap was — that history is what the capstone's retrospective mines.

---

## How the Reference Project Demonstrates This Loop

Fired Up Pizza is the reference project shipped with this repo. Look at:

- [`reference-project/fired-up-pizza/tickets.md`](../../../reference-project/fired-up-pizza/tickets.md) — the backlog that *would* be slung to agents
- [`reference-project/fired-up-pizza/docs/PROJECT_MANIFEST.md`](../../../reference-project/fired-up-pizza/docs/PROJECT_MANIFEST.md) — the manifest the agents read before every task

The agent instructions file you just wrote is the starter form. By C1, you'll have added sections for six agents — or pushed those role-specific rules into per-agent `packs/*/prompts/*.md` files, like the reference does. That's the transition from "single-agent config" to "factory config."

---

## Recommended Prompts

### In the Bead Description (Agent's First Read)

```
Implement the user story below, following every rule in CLAUDE.md.

<paste user story>

Before writing code:
1. Read CLAUDE.md completely. If any rule conflicts with this story,
   stop and say so.
2. Read the two files named in Technical Notes.
3. Post a 3-step plan as a bead comment.

After writing code:
1. Run every command in Quality Gates.
2. Commit with a conventional-commit message.
3. If you had to deviate from the plan, note it.
```

### When Updating `CLAUDE.md` Between Slings

You're not prompting the agent here — you're editing the file that prompts the agent. But verbalize the delta as a PR-sized sentence:

```
Added rule under Quality Gates: "No inline styles in React components.
Use Tailwind classes or CSS modules only." Reason: sling 2 produced
an inline-style CartTotal.tsx that violated repo convention.
```

This gives your future self the context to judge whether the rule was right.

---

## Inline Insight: How an Agent Actually Reads `CLAUDE.md`

Understanding how the agent parses `CLAUDE.md` helps you write rules that actually fire. Here's roughly what happens:

1. **Session start.** When `gc sling` fires, Gas City launches Claude Code with the rig directory as the working directory. Claude Code looks for `CLAUDE.md` in the working directory and loads its full contents as part of the system prompt.
2. **Section parsing.** The model doesn't have a special `CLAUDE.md` parser — it just treats the file as plain text. Section headings help it retrieve relevant chunks when reasoning, but there's no "Role section" data structure under the hood. It's all continuous text to the model.
3. **Rule weighting.** Imperatives ("NEVER", "ALWAYS", "MUST", "Run this command") weigh heavier than hedges ("try to", "consider", "prefer"). Structured lists weigh heavier than prose. Named commands weigh heavier than described outcomes.
4. **Instruction decay.** In long sessions, earlier parts of the system prompt receive less attention per token than recent conversation. This is why the 3-line plan step matters: externalizing the plan into a bead comment makes it part of the *recent* conversation again when the agent is coding.
5. **Conflict resolution.** When two rules contradict, the more specific one wins. "All commits must pass tests" + "Fix build errors before testing" → the agent will fix build errors before running tests, because that sequencing rule is more specific.

Practical implications:

- **Put the most important rules near the top.** The skeleton puts Project Context before Role before Iteration Rule because each section depends on knowing the ones above it.
- **Name commands verbatim.** "Run tests" is weaker than "Run `npm test`". The second one gives the agent a directly executable instruction.
- **Use structured lists for sequences.** A numbered Iteration Rule is followed step-by-step; a paragraph describing the process is sometimes followed, sometimes skipped.
- **Re-state critical rules in the relevant section.** If "never edit main" is a Project Context rule *and* the first step of the Iteration Rule, the agent is twice as likely to remember it.

---

## Exit Criteria

- [ ] `CLAUDE.md` (or `AGENTS.md`) committed to your project repo with all 4 sections (Role, Iteration Rule, Quality Gates, Decision Log) present and specific to your project
- [ ] Feature implementation passes all quality gates
- [ ] `DECISIONS.md` has at least one L1 entry documenting what changed between slings, why, and lessons learned
- [ ] Bead closed in Gas City (`bd close`)
- [ ] Zero manual code edits — every iteration went through the agent instructions file

**L1 blocks L2.** Don't move on without meeting exit criteria — you cannot meaningfully add a second agent in L2 when the single-agent loop isn't working.

---

## Quality Bar

When you review your own work at the end of the lab, check each of these:

- **`CLAUDE.md` Specificity** — Every rule names a concrete thing (command, path, filename). No generic phrases like "good code" or "clean output." Run a grep for words like "prefer", "try", "consider", "maybe" — each one is a candidate for rewriting as an imperative.
- **Iteration Rule Completeness** — The rule covers the happy path (implement, commit) and the failure path (what to do when a quality gate fails). A rule that only covers success is a rule that's never tested.
- **Quality Gates Executability** — Each gate is a single shell command with a zero / non-zero exit code. If the agent has to interpret output subjectively, it's not a gate — it's a suggestion.
- **Decision Log Integrity** — Every rule you added mid-lab has a matching `DECISIONS.md` entry with date, bead ID, rule, and reason. The log is the audit trail of your config evolution.
- **Config Discipline** — Zero manual code edits. Every correction was a `CLAUDE.md` diff + re-sling. If you cheated once, go back, revert the manual edit, add the rule, re-sling. The habit is what matters.

---

## Test Scenarios

Once you've completed the base lab, try these variations to stress-test your `CLAUDE.md`:

### Scenario 1: A Deliberately Vague Story

Create a bead with a weakly-specified story:

```bash
bd create \
  --title "Feature: Improve the cart UX" \
  --labels ready-to-build \
  --description "Make the cart page feel nicer and more professional."
```

Sling it to `your-project/claude`. **Expected behavior:** The agent either refuses (if your Iteration Rule says "if acceptance criteria are missing, post a comment and stop") or produces something arbitrary. This tests whether your rules force specificity out of the bead before coding starts. If the agent plowed ahead, add to the Iteration Rule: "Before writing any code, confirm the bead has at least two concrete acceptance criteria. If not, post a comment listing what's missing and stop."

### Scenario 2: A Story That Crosses Convention Lines

Create a bead that tempts convention violations:

```bash
bd create \
  --title "Feature: Inline-style cart total for quick prototype" \
  --labels ready-to-build \
  --description "Add the cart total to src/components/Cart.tsx using inline styles for speed. We'll refactor later."
```

Sling it to `your-project/claude`. **Expected behavior:** The agent ignores the "use inline styles" hint in the bead and uses your project's actual styling convention (Tailwind, CSS modules, etc.), because your `CLAUDE.md` Project Context forbids inline styles. This tests whether `CLAUDE.md` rules override per-bead instructions. If the agent complied with the bead, strengthen your Project Context rule to explicitly outrank bead-level overrides.

### Scenario 3: Consecutive Small Stories (Pipeline Durability)

Create three small beads in sequence, sling each, close each. You're testing that the `CLAUDE.md` you converged to for the first story still works for unrelated stories. **Expected behavior:** All three ship within target (≤3 slings each) without requiring `CLAUDE.md` edits specific to each. If you had to add a new rule per bead, your rules are too narrow — generalize them.

---

## Common Issues & Solutions

### Issue 1: Agent ignores `CLAUDE.md` entirely
**Solution:** Confirm `CLAUDE.md` is in the rig root (your project repo's root), not a subdirectory. Check with `gc session peek your-project/claude` — the first thing the agent reads should be `CLAUDE.md`. If it isn't, either the rig's working directory is wrong (`gc rig list` to confirm) or the `CLAUDE.md` file is somewhere else.

### Issue 2: Quality gates fail with the same error twice
**Solution:** Your rule is too vague. Move from principle → imperative: "Tests must pass" → "Run `npm test`. If any test fails, do not commit. Read the error, fix the cause, re-run." The agent follows imperatives; it treats suggestions as optional.

### Issue 3: Agent takes 40+ minutes on a simple story
**Solution:** Your story is too big, or your `CLAUDE.md` is under-specified. Kill the session (`gc session kill <session-id>` — find the id via `gc session list`), tighten the story scope to one component, tighten `CLAUDE.md`'s Iteration Rule to explicitly limit scope ("Only modify files named in Technical Notes"), file a fresh bead, re-sling.

### Issue 4: `gc status` shows no `claude` agent
**Solution:** `gc status` should show at least `claude` (pool) and `your-project/claude` (pool). If not, check that you ran `gc restart` after `gc rig add`, and that `my-factory/city.toml` has `provider = "claude"` under `[workspace]`. The implicit agent is derived from the workspace provider — if the provider is unset or mismatched, no implicit agent appears.

### Issue 5: You caught yourself typing into Claude chat
**Solution:** Stop immediately. That correction is invisible to your next sling. Undo the agent's current work, translate your chat correction into a `CLAUDE.md` rule, re-sling with a fresh bead. The point of L1 is to feel how obvious this mistake is once you're watching for it.

### Issue 6: Agent commits code that fails tests it didn't run
**Solution:** Add an explicit "After implementing, run every command in Quality Gates in order, before committing. If any command fails, do not commit — fix and re-run" step to the Iteration Rule. Some agents optimize for shipping quickly and skip the gates unless forced.

### Issue 7: Agent changes files outside the feature scope
**Solution:** Add a scope-lock rule to `CLAUDE.md`: "Only modify files listed in the bead's Technical Notes plus tests for those files. NEVER modify configuration files, CI, or unrelated modules without explicit instruction." The agent defaults to expansive scope unless told otherwise.

### Issue 8: Agent invents APIs, libraries, or files that don't exist
**Solution:** Add to Project Context: "Only reference files, functions, and dependencies that currently exist in the repo. Before using an import, verify the target file contains that export. Never assume a utility exists — search for it first." Claude defaults to "helpful completion" over "literal truth" unless reined in.

### Issue 9: `gc sling` returns "agent not found"
**Solution:** The agent name in the command doesn't match any registered or implicit agent. Use `gc status` to see what's available — `claude`, `codex`, etc. (implicit), plus anything from imported packs. The rig-scoped form is `<rig-name>/<agent>` — the slash matters, and the rig name must match `gc rig list` output.

### Issue 10: Session won't close after sling ends
**Solution:** `gc session list` shows all active sessions. Pick the stuck one and close it: `gc session close <session-id>` (permanent close) or `gc session kill <session-id>` (force-kill; reconciler will restart on next sling). If sessions leak every time, the implicit agent's `idle_timeout` default may be longer than you want; override by shipping a pack-based `claude` agent in L2+ with a tighter timeout.

### Issue 11: Agent posts a plan but doesn't follow it
**Solution:** The Iteration Rule needs a self-check step: "After posting the plan, implement each step in order. Before moving to the next step, verify the previous step's output passes its tests." Plans without enforcement are decoration.

### Issue 12: `gc events --follow` shows nothing
**Solution:** Events are only emitted during active sessions. If no agent is running, the stream is silent — not broken. Sling a bead, then watch events. If events still don't appear, check that the api server is up (`gc status` should show `api: <host>:<port>`); events require the api server.

---

## Command Cheat Sheet

Every command you ran, in order:

```bash
# SETUP (Step 1)
cd my-factory
gc register .
gc rig add ../../path/to/your-repo
gc rig list
# (Bootstrap your rig's output directories — see Step 1.4)

# OPTIONAL INTEGRATIONS (Step 2)
# Add the workshop pack to the rig via rig-scoped import in my-factory/city.toml:
#   [rigs.imports.workshop]
#   source = "../packs/workshop"
cp ../packs/workshop/env.example ../../path/to/your-repo/.env
gc restart
gc doctor

# VERIFY IMPLICIT CLAUDE AGENT (Step 3)
gc restart
gc status     # should list `claude` and `your-project/claude`

# WRITE CLAUDE.MD (Step 4)
# Edit ~/path/to/your-repo/CLAUDE.md
git checkout -b claude-md-setup
git add CLAUDE.md
git commit -m "chore: add CLAUDE.md for claude agent (L1)"

# CREATE BEAD (Step 6)
cd ~/path/to/your-repo
bd create \
  --title "Implement: Show Order Total in Cart" \
  --labels ready-to-build \
  --description "$(cat <<'EOF'
... your story ...
EOF
)"
bd list

# SLING + WATCH (Step 7)
gc sling --nudge your-project/claude yr-abc
# In parallel terminals:
gc session peek your-project/claude
gc events --follow
gc status
bd show yr-abc

# VERIFY (Step 8)
git log -5 --oneline
git diff HEAD~1
# Run your project's quality gates (lint, tests, type check, build)

# ITERATE on CLAUDE.md if gates fail (no code edits!)
# Edit CLAUDE.md
git reset --hard HEAD~1
bd create \
  --title "Implement: Show Order Total in Cart (v2)" \
  --labels ready-to-build \
  --description "$(cat <<'EOF'
... same user story ...
EOF
)"
gc sling --nudge your-project/claude <new-bead-id>

# CLOSE (Step 9)
git add CLAUDE.md DECISIONS.md
git commit -m "docs: update agent rules after first sling (L1)"
git push -u origin claude-md-setup
bd close <final-bead-id> --note "Feature shipped. CLAUDE.md updated."
```

---

## Quick Reference: What You Built

| Component | Location | What It Does |
|-----------|----------|--------------|
| City | `my-factory/` | The workspace where agents and beads live. Registered via `gc register`. |
| `pack.toml` | `my-factory/pack.toml` | The portable pack definition — imports, providers, agent defaults |
| `city.toml` | `my-factory/city.toml` | Deployment config — rigs, workspace provider, substrate choices |
| Supervisor | Background launchd service | Keeps agents alive between terminal sessions |
| Rig | Registered via `gc rig add` | Your project repo, registered with the city. One city can have many rigs. |
| Implicit `claude` agent | Built into gc | Gas City ships with `claude`, `codex`, `gemini` etc. as built-in agents. Reads `CLAUDE.md` / `AGENTS.md` from the rig's root. |
| `CLAUDE.md` | `your-repo/CLAUDE.md` | The *only* place agent behavior is defined. Edit this, never the chat. |
| `AGENTS.md` | `your-repo/AGENTS.md` (alternative name) | Identical to `CLAUDE.md` in structure. Use this name for Codex, Cursor, Gemini. |
| `docs/PROJECT_MANIFEST.md` | `your-repo/docs/PROJECT_MANIFEST.md` | Tech stack, conventions, domain model. Read by every agent before every task. |
| `DECISIONS.md` | `your-repo/DECISIONS.md` | Running log of what you changed in `CLAUDE.md` and why |
| Bead | Created via `bd create --title ... --labels ...` | A unit of work an agent can pick up and close. Has title, description, status, labels. |
| Bead database | `.beads/` in each rig | Per-rig storage for all beads. Managed by `bd`. |
| Sling | `gc sling --nudge your-project/claude <bead>` | Routes a bead to an agent and wakes the session |
| Session | `gc session list` shows active sessions | Where the agent actually runs. Peek with `gc session peek`, attach with `gc session attach`. |
| Quality gates | Defined in `CLAUDE.md` Quality Gates section | Binary pass/fail per run; the agent's exit criteria |
| Event stream | `gc events --follow` | Real-time city-wide log of agent activity |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `gc status` doesn't list a `claude` agent | `my-factory/city.toml` `[workspace]` section is missing `provider = "claude"`, or you haven't run `gc restart` since `gc rig add`. Set the provider, restart, check `gc status` again. |
| `gc sling` returns "agent not found" | The agent name in the command doesn't match an implicit agent or a pack-defined agent. Use `gc status` to see what's available. Remember the rig-scoped form is `<rig-name>/claude` (slash, not dash). |
| `gc sling` returns "bead not found" | Bead ID typo, or you're running `gc sling` against the wrong rig. `bd list` shows beads in the current rig. |
| Agent runs but never reads `CLAUDE.md` | File is in a subdirectory, not the rig root. `ls ~/path/to/your-repo/CLAUDE.md` must succeed. |
| Agent makes the same mistake after re-sling | Your rule is a suggestion ("Prefer X"), not an imperative ("NEVER do Y"). Rewrite as imperative. |
| Quality gates pass but feature is wrong | Acceptance criteria were too loose. Strengthen the ACs in the bead description, not the prompt. |
| `gc doctor` warns about missing `LINEAR_API_KEY` etc. | Expected — only core tool checks are required. Other checks only fire if you fill in env vars for that service. |
| You caught yourself typing into chat | Stop, undo the agent's work, translate your chat correction into a `CLAUDE.md` rule, file a fresh bead, re-sling. This *is* the lesson. |
| Agent takes 40+ minutes on a simple story | Story too big or rules too loose. Kill the session (`gc session kill <session-id>`), tighten scope in `CLAUDE.md` and in the bead, file a fresh bead, re-sling. |
| Session won't close | `gc session close <session-id>` (permanent) or `gc session kill <session-id>` (force; reconciler will restart). |
| `gc restart` hangs | Check the supervisor process: `ps aux \| grep gascity`. If stuck, `launchctl unload ~/Library/LaunchAgents/com.gascity.supervisor.plist` then `gc register my-factory` again. |
| Agent commits to main instead of a feature branch | Add to CLAUDE.md: "Before making any code changes, ensure you are on a feature branch. If on main, run `git checkout -b <bead-slug>` first." |
| Agent's commit message isn't conventional-commits | Output Format in CLAUDE.md needs an example. Add: "Commit format: `feat(scope): short description`. Example: `feat(cart): show order total in cart view`." |
| `bd show` returns nothing | Bead ID is wrong or from a different rig. `bd list` to see all beads in the current rig. |
| Agent asks a question and pauses | Your Iteration Rule doesn't tell it what to do when stuck. Add: "If you cannot proceed, post a bead comment describing the blocker and exit. Do not ask the user interactively." |
| `.env` variables not picked up | Gas City loads `.env` at session start, not at sling. Run `gc restart` after editing `.env`. |

---

## After the Sling: A Retrospective Checklist

Before starting L2, walk through this retrospective on your L1 run. It takes 5 minutes and surfaces the gaps you'll want to close before adding more agents.

1. **How many slings did it take?** If 1, you probably got lucky — your story was simple and your `CLAUDE.md` was reasonable. If 2–3, you hit the intended learning curve. If 4+, one of your rules is fighting one of your project conventions — identify which.
2. **What was the first rule you added mid-lab?** This is the rule your workflow card missed in W1. File it in `DECISIONS.md` with a clear "why W1 missed this" explanation — that's the exact gap you want to close in future workflow card revisions.
3. **Did you ever type into the chat?** If yes, even once, re-run Scenario 2 from Test Scenarios. The muscle memory for config-over-chat is the single most important habit the curriculum builds.
4. **Did the agent commit to a feature branch?** `git branch --show-current` should show `claude-md-setup` or similar, not `main`. If it's on `main`, add a branch-discipline rule to `CLAUDE.md` before L2 — you don't want six agents pushing to main in L4.
5. **Did the agent follow the Output Format?** Check `git log --oneline -3`. Every commit should match `type(scope): description`. If any don't, your Output Format needs a concrete example (not just the pattern).

Bring your answers to L2 — the gaps you identify now will become per-agent rules in `packs/planner/agents/planner/prompt.template.md` and beyond.

---

## Next Steps

In **L2**, you'll:
- Install your first two agent packs (`packs/planner`, `packs/architect`)
- Split agent behavior into per-agent prompt files — each with its own Role, Inputs, Output Format, Quality Gate, and Process
- Produce your first **Work Package** and **ADR** — the two artifacts that downstream agents will consume

The single-agent loop you just built is the atomic unit of the factory. L2–L4 add more agents on top of the exact same iteration pattern: create bead → sling → watch → review → edit config → re-sling. If that loop feels solid now, the rest of the curriculum is "do it again, with more agents."
