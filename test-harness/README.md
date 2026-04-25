# Test Harness

Every executable check for this repo lives here. Five harnesses at three layers of rigor:

| Harness | Layer | What it proves | Live LLMs? | Runtime |
|---|---|---|---|---|
| `lesson-pack-lint.py` | Static | Active curriculum content satisfies `specs/content-architecture.md` lesson contracts | no | ~1 s |
| `migration-check.sh` | Static | TOML + directory layout matches Pack v2 convention across all 23 `pack.toml` files | no | ~2 s |
| `behavioral-smoke.sh` | Setup | A scratch factory boots and exposes every agent's doctor check + pack commands | no | ~60 s |
| `tutorial-check.sh` | Setup | The README quickstart commands for `my-factory/`, W2 checkpoint, and L2 checkpoint all run end-to-end *up to* `gc start` | no | ~2–5 min |
| `tutorial-walkthrough.sh` | Live | A real student flow produces real artifacts from real LLM agents against our factory | **yes** | ~5–15 min per lesson |

Run them in that order for an incremental signal from "the files are correct" to "the factory actually does work." Each harness has its own README-like preamble at the top of the script.

---

## 0. `lesson-pack-lint.py` — content architecture lint

This is the executable form of `specs/content-architecture.md`. It reads
`test-harness/lesson-contracts/*.toml` and checks that each active lesson has:

- a self-contained `packs/lessons/<lesson>/` pack
- local rig-scoped role agents
- a FormulaV2 `contract = "graph.v2"` entry formula
- binding-qualified routes such as `lesson.planner`
- artifact metadata for each graph step
- graph-worker prompt sections
- docs that show city-wide lesson selection, existing-rig import sync, and one
  `gc sling <rig>/lesson.<agent>` entrypoint

It also scans active curriculum paths for old label/manual-pack patterns such
as `packs/all`, `default_rig_includes`, `bd ready --label`, and
`gc all wake-downstream`.

Use it as the red-green driver for the port:

```bash
test-harness/lesson-pack-lint.py --lesson L2 --no-repo-scan
test-harness/lesson-pack-lint.py --lesson L2
test-harness/lesson-pack-lint.py
```

The first command gives focused lesson-contract feedback. The second adds
shared root/content checks. The third is the final all-lessons gate.

The current repo is expected to be red until the lesson packs and docs are
ported. That is intentional; the linter is the migration checklist, not a
statement that the pre-port content is already compliant.

---

## Governing principle: scripts and student-facing READMEs must stay in sync

The walkthrough scripts (`test-harness/walkthroughs/<lesson>.sh`) are not private automation that can take shortcuts a student wouldn't take. They are the **live correctness check on what we tell students to type**. Every shell command the script runs should be something a student following `activities/<track>/<lesson>/README.md` would type. When they diverge, we have a bug — either in the script, in the README, or in Gas City itself.

The iteration loop:

1. **The script is the experimental vehicle.** Get it running end-to-end against a real factory. Iterate on the commands, budgets, and handoff sequencing until it produces the lesson's deliverables reliably.
2. **The README is the destination.** Once the script reliably works, the student-facing activity README **must say exactly what the script runs** — same command shapes, same order, same bead/label conventions. If the README asks students to do X but the script had to do Y to succeed, the README is wrong and needs updating.
3. **A script "cheat" is a bug report.** If the script has to invoke a helper that bypasses what a student would type, that's a signal — either Gas City is missing a documented path, or the README is incomplete. File it as a WORKSHOP_AUTHOR_NOTES entry (see §13-§14 for examples) and fix the root cause rather than papering over it in the script.

Concretely: if the L3 activity README tells a student `bd create --label needs-architecture --depends-on <planner-bead>` + `gc sling`, then `L3.sh` runs exactly that. If during iteration we discover the README's instructions don't actually produce the deliverable (because the shipped pack's behavior differs, or gc has an unexpected constraint), we update the README to match what works — we don't leave the student with instructions that don't work.

The goal of a successful harness run is **both** a green lesson script *and* a high-confidence README. A green script on its own doesn't ship — it has to produce an instruction set a student can follow and succeed with.

---

## 1. `migration-check.sh` — static structural invariants

Asserts 10 invariants across every `pack.toml` in `packs/` and in the `activites/` checkpoint trees:

- Every migrated pack has `schema = 2`
- Every agent-bearing pack has `agents/<n>/{agent.toml, prompt*.md, overlay/}` laid out correctly
- No v1 leftovers (`prompts/`, `overlays/default/`, `scripts/`, `formulas/orders/`, `*.formula.toml`, `packs/actual/`, etc.)
- Every `commands/<n>/` has both `run.sh` and `command.toml`; same for `doctor/<n>/`
- Orders are flat `orders/<n>.toml` (not `orders/<n>/order.toml`)
- Formula body references use `gc <binding> <cmd>` pack-command form, not `$PACK_DIR`-relative paths

Fails fast with per-file line-number-ish messages. No factory bootstrap; pure filesystem checks. Safe to run on every branch.

```bash
bash test-harness/migration-check.sh
```

Exit 0 when all 23 packs pass the 10 invariants.

---

## 2. `behavioral-smoke.sh` — scratch factory + expected pack exposure

Spins up a throwaway factory under `/tmp/sfi-smoke/`, registers it with the supervisor, and asserts:

- `gc doctor` runs cleanly against our shipped packs (only the two documented deprecation warnings)
- Every canonical agent pack's `:check-<agent>` doctor check is present in the output
- Every pack command shipped in `packs/all/` (e.g. `wake-downstream`) appears in `gc <binding> --help`
- Both `activites/workshops/W2/.../packs/` and `activites/labs/L2/.../packs/` checkpoint factories also boot cleanly when their templates are copied to live files

No live agents — no `bd create`, no LLM calls. This is the "did we wire the pack structure into gc correctly" check.

```bash
bash test-harness/behavioral-smoke.sh
```

Exit 0 when all three factories (main + 2 checkpoints) report clean `gc doctor` + expected doctor check IDs + expected pack commands.

---

## 3. `tutorial-check.sh` — README setup commands actually work

Exercises the *setup* half of three student-facing READMEs:

1. `my-factory/README.md` main quickstart — template copy, `gc register`, `gc rig add`, doctor
2. `activites/workshops/W2/README.md` — W2 checkpoint factory quickstart (including deployer discovery via `gc config show`)
3. `activites/labs/L2/README.md` — L2 checkpoint factory quickstart

For each lesson the harness creates a scratch dir, runs every shell command the README tells a student to run up to the point where live agent sessions would be required, and asserts:

- `gc version ≥ 0.15.0`
- Template→runtime copy works
- `gc register --name <unique>` reports "Registered city" (succeeds even if the first reconcile tick races)
- `gc rig add <scratch-project>` succeeds
- `gc doctor` emits the two documented deprecation warnings and every expected `:check-<agent>` doctor ID

**Divergences** from the literal README text (registry-isolation unique `--name`, scratch rig path instead of `~/Projects/…`, etc.) are logged to `/tmp/sfi-tutorial-check/divergences.log` so README authors can see exactly where the harness paraphrased.

The harness **deliberately stops short** of `gc start`, `bd create --label …`, agent waking, handoff chain. Those require a live `claude` CLI and real token spend — that's what `tutorial-walkthrough.sh` is for.

```bash
bash test-harness/tutorial-check.sh
```

Exit 0 when all three lessons green (plus a divergence log a reader can audit).

---

## 4. `tutorial-walkthrough.sh` — end-to-end with **real live LLMs**

Drives a factory through a real student flow: registers, adds a rig, files a bead, waits for the agents to produce tangible work, and verifies the output.

This is the only harness that:
- Requires `claude auth status` to exit 0 (it uses your real Claude Code login)
- Spawns real tmux sessions, spends real tokens, takes real wall-clock minutes
- Produces real artifacts in a scratch rig (ADRs, work packages, commits, etc.)

```
test-harness/
├── tutorial-walkthrough.sh         # thin dispatcher — positional <lesson> args
├── walkthroughs/
│   ├── _common.sh                  # helpers: wait_for, wait_for_bead_label,
│   │                               #          assert_artifact_has_sections,
│   │                               #          purge_stranded_walkthrough_cities,
│   │                               #          per-lesson log + state.env plumbing
│   └── my-factory.sh               # first real lesson (v1)
└── tutorial-walkthrough-rig/       # minimal bundled hello-world rig
    ├── package.json                # Node.js "calculator" project, Jest devDep
    ├── src/calculator.js           # add/subtract — room for agents to extend
    ├── test/calculator.test.js     # passing tests establishing the pattern
    ├── CLAUDE.md                   # project rules the Planner/Architect read
    └── README.md                   # "this is a harness fixture, not example code"
```

### Dispatcher CLI (v1 — positional only)

```bash
bash test-harness/tutorial-walkthrough.sh                     # run all known lessons
bash test-harness/tutorial-walkthrough.sh my-factory          # run one lesson
TUTORIAL_WALKTHROUGH_DRY_RUN=1     bash test-harness/tutorial-walkthrough.sh my-factory
TUTORIAL_WALKTHROUGH_KEEP_SCRATCH=1 bash test-harness/tutorial-walkthrough.sh my-factory
```

`--lesson` / `--from` flags get added when a second lesson lands; positional dispatch is simpler for the one-lesson world.

### Per-lesson script contract

Each `test-harness/walkthroughs/<lesson>.sh` is a standalone bash script that:

- Sources `_common.sh` (reads the `WALK_*` env vars the dispatcher provides)
- Defines `lesson_prerequisites_check()` (asserts the state prior lessons must have produced)
- Defines `lesson_run()` (the actual body)
- Exits 0 on success, 77 if prerequisites are missing, non-zero otherwise
- Optionally writes state to `$WALK_STATE_ENV` via `save_state VAR1 VAR2 …` so chained lessons can consume it

### Current lesson: `my-factory.sh`

Mirrors `my-factory/README.md` steps 1–8 end-to-end:

1. Pre-flight (`gc` 0.15+, `claude` authenticated, `jq tmux git bd` on PATH, no stranded sfi-walkthrough-* cities)
2. Scratch setup (`/tmp/sfi-tutorial-walkthrough/<run_id>`, isolated `TMUX_TMPDIR`)
3. Copy `my-factory/{pack,city}.toml.template` → live files, symlink repo `packs/`
4. `gc register --name sfi-walkthrough-<run_id> .`
5. Copy `tutorial-walkthrough-rig/` into scratch + `git init` + `gc rig add`
6. `chmod 700 ../.beads` + rig-side `bd config set types.custom convoy`
7. `gc doctor --fix` + wait for supervisor responsive + wait for all 8 agents visible
8. `bd create --label needs-architecture` → **wait for tangible work** (new files in rig OR bead closed OR downstream label appears) within 15 min

Success criterion: **the factory actually did something measurable to the rig.** The harness doesn't care which specific handoff fired — it cares that a real student would open their project dir and see work there.

Verified live: the Architect reads `CLAUDE.md`, picks up the bead, writes `docs/adr/0001-multiply-function.md` (~3.6KB of real architectural reasoning), closes the bead. Typical wall-clock: 3–10 min depending on gc bootstrap speed.

### Observability while the walkthrough runs

Three native gc streams let you watch the factory in real time:

- `gc events --follow` from the scratch factory — every bead transition, order fire, session state change
- `gc session list` — who's creating / active / asleep right now
- `gc session peek <name>` / `gc session logs <name>` — the actual LLM output from an agent

Use those when iterating on a failing walkthrough (the harness's own log is terse by design).

### State when the walkthrough fails

- `TUTORIAL_WALKTHROUGH_KEEP_SCRATCH=1` preserves `/tmp/sfi-tutorial-walkthrough/<run_id>/` after exit — factory, rig, `.gc/events.jsonl`, walkthrough log all intact for post-mortem
- Pre-flight auto-purges any leftover `sfi-walkthrough-*` cities from prior killed runs via `gc unregister`
- `gc stop` + tmux kill + scratch removal happens in a cleanup trap so even SIGINT leaves state sane

---

## Shared library

`test-harness/lib/tutorial-common.sh` — setup-phase helpers shared by `tutorial-check.sh` and the walkthrough's `_common.sh`:

- `run_id` generation + `cleanup()` trap
- `divergence()` / `step_pass()` / `step_fail()`
- `assert_gc_version_ge_015`
- `assert_gc_doctor_healthy <factory-dir>`
- `assert_agent_doctor_checks_present <doctor_out> <agent>…`

Both setup and live harnesses source this. The walkthrough also sources its own `walkthroughs/_common.sh` for live-only helpers (`wait_for`, artifact checks, state.env plumbing).

---

## Adding a new lesson

1. Write `test-harness/walkthroughs/<name>.sh` following the contract above (copy `my-factory.sh` as a template)
2. Add `"<name>"` to `ALL_LESSONS` in `test-harness/tutorial-walkthrough.sh`
3. Dry-run it: `TUTORIAL_WALKTHROUGH_DRY_RUN=1 bash test-harness/tutorial-walkthrough.sh <name>`
4. Live-run it: `TUTORIAL_WALKTHROUGH_KEEP_SCRATCH=1 bash test-harness/tutorial-walkthrough.sh <name>` — expect it to fail first time; iterate using the `gc events --follow` + `gc session peek` observability streams
5. Commit the lesson + update this README if a new primitive was added to `_common.sh`

Lessons chain by default: each one sees what prior lessons wrote to `$WALK_STATE_ENV`. `my-factory.sh` exports `WALK_FACTORY`, `WALK_RIG`, `WALK_CITY_NAME`, and `WALK_MYFACTORY_BEAD_ID`; a future `L2.sh` would consume those and export its own state for later lessons.
