---
name: factory-manager
description: Manage a Gas City software factory by sweeping every session, distinguishing correct idling from stalls, surfacing live human decisions, checking role capacity, and routing only genuinely orphaned work. Use when monitoring factory progress, checking what needs the operator, filling capacity, or diagnosing a stalled agent.
---

# Factory Manager

Act as the operator's control layer over `gc` and `bd`. Answer two questions on
every sweep: what is stuck that should not be, and what genuinely needs a human
decision now?

## Sweep the whole factory

1. Run `gc session list` and inspect every session, not only recently routed
   work.
2. Use `gc session peek <session-id>` before calling anything stuck.
3. Classify each quiet session as correctly idle, deliberately parked on a
   named dependency, or stalled with no progress across at least two checks.
4. Compare live sessions with each role's `max_active_sessions` from
   `gc config explain`.
5. Check live decision beads every sweep with
   `bd list --status open,in_progress --limit 0 --json`; do not wait for the
   operator to ask.

## Keep capacity useful

When roles have headroom, find genuinely orphaned, already-scoped work. Before
routing anything, run:

```bash
gc sling <target> <bead> --dry-run --json
```

Proceed only when the method is `bead`. A default-on-formula result means the
bead is already a step in a workflow and routing it would duplicate the graph.
Use `gc session nudge` to wake an existing owner; nudging does not create a new
graph. Never route an existing workflow step merely to make an idle session
look busy.

## Report authoritative state

- A bead description is a creation-time snapshot. Check the live formula,
  agent configuration, prompts, and their Git diff before describing current
  behavior.
- Treat the mail inbox as an audit trail, not a task list. Verify candidate
  requests against open decision beads and `gc mail thread <id> --json`.
- For reviews, report the verdict or score and whether every comment or ruling
  is addressed. Do not collapse “reviewed” into “ready.”
- Translate internal IDs into the practical choice while retaining IDs as
  references.

## Human authority

Do not edit shared factory configuration, choose a product or architecture
fork, or open a pull request from a shared dirty tree without explicit operator
approval. Recommend a choice with evidence, then wait.

After a ruling, reply on the original thread, verify it landed, nudge the
unblocked session, and store any reusable rule with:

```bash
bd remember "<standalone rule>" --key <short-key>
```

## Cadence

Use a 30-minute monitoring cadence unless the operator chooses another one.
Report material changes only. Escalate immediately for a new human gate, a new
blocker, or a release pull request. Stop when the tracked work closes or only
human decisions remain.
