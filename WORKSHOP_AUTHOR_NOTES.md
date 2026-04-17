# Workshop Author Handoff Notes

This file flags content that needs judgment-call rewrites the mechanical doc-fix pass couldn't automate. Each item cites the file(s) and why the fix is teaching-content rather than find-and-replace.

Companion plan: `plans/fix-stale-docs.md`.

---

## 1. Curriculum files teaching v1 `[[agent]]` blocks

Gas City Pack v1 exposed agent config as `[[agent]]` TOML blocks inside `pack.toml` (or `city.toml`). In Pack v2, agents live at `agents/<name>/agent.toml` inside a pack directory, and the `[[agent]]` block no longer exists in pack.toml at all. Several curriculum files teach students to author, tune, or read `[[agent]]` blocks directly. These lessons cannot be corrected by a string replace — they need rewrites.

Regenerate the current hit list before editing:

```bash
rg -n '\[\[agent\]\]' curriculum/ -g '*.md'
rg -ln '\[\[agent\]\]' curriculum/ -g '*.md'
```

**Files known to teach `[[agent]]` (verify before editing):**

- `curriculum/labs/L1/README.md` — the lab's `[[agent]]` block tuning exercise (`idle_timeout`, `max_active_sessions`, etc.). In v2 these fields live in `agents/<name>/agent.toml`. Rewrite around the v2 per-agent `agent.toml` surface. Roughly 14 hits.
- `curriculum/labs/L3/README.md` — references `[[agent]]` instructional content. Roughly 14 hits.
- `curriculum/labs/L4/README.md` — references `[[agent]]` instructional content. Roughly 15 hits.
- `curriculum/workshops/W3/README.md` — orchestrator instructions use `[[agent]].name` as the stage-binding key. V2 pack.toml has no `[[agent]]` block; the correct binding is the `agents/<n>/` directory name. Needs curriculum rewrite, not string replace. Roughly 12 hits.
- `curriculum/capstone/C1/README.md` — `[[agent]]` city.toml teaching example. Roughly 15 hits.

---

## 2. Phantom gc commands used throughout curriculum

Three commands appear repeatedly in curriculum but do not exist in gc 0.15:

| Phantom command | v2 equivalent (pick per instructional intent) |
|---|---|
| `gc watch <agent>` | `gc session attach <name>` (interactive tmux attach) OR `gc session peek <name>` (view output without attach) |
| `gc session stop <name>` | `gc session close <name>` (permanent close) OR `gc session kill <name>` (force-kill; reconciler restarts) OR `gc session suspend <name>` (save state, free resources) |
| `gc orchestrate <...>` | No direct equivalent. W3 and C1 teach an orchestrator subsystem that was removed or reshaped in 0.15. Decide: rewrite to teach formula + `gc convoy` handoff, or document that orchestrate is no longer available. |

Regenerate the current hit list:

```bash
rg -ln 'gc watch|gc orchestrate|gc session stop' curriculum/ -g '*.md'
```

Roughly 40 `gc watch` hits plus `gc orchestrate` and `gc session stop` hits across L1/L2/L3/L4/W3/W4/C1 at last count. Every instance needs a semantic decision (attach vs peek, close vs kill vs suspend, rewrite orchestrate teaching vs drop it).

---

## 3. `includes = [...]` and `gc service restart` in curriculum PROMPT.md files

Three files contain mechanical-looking hits that are actually inside teaching blocks and should be reviewed together with the `[[agent]]` rewrites above (not auto-fixed):

- `curriculum/labs/L2/PROMPT.md` — `includes = [...]`, `gc service restart`
- `curriculum/labs/L3/PROMPT.md` — same
- `curriculum/labs/L4/PROMPT.md` — same

Mechanical replacements (`includes = [...]` → `[rigs.imports.<binding>]`, `gc service restart` → `gc restart`) are safe, but the surrounding prose often explains *why* a student is editing the city.toml a certain way. Prefer a full rewrite in step with the `[[agent]]` teaching rewrite above.

---

## 4. `packs/workshop/README.md` Discord integration claim

`packs/workshop/README.md:71` (the Communication table) lists Discord (`DISCORD_*` env var). There is no Discord doctor check, no Discord MCP server entry, no Discord env var use anywhere in the pack. Decide:

- (a) Discord integration is planned future work — leave the row with a note.
- (b) Discord is not planned — remove the row.

Pack authors should not ship docs for an integration that isn't actually wired.

---

## 5. `packs/workshop/overlay/.claude/settings.json` MCP list

The shipped MCP servers are: **datadog, github, grafana, linear, posthog, sentry, slack**. No gitlab. The README was updated to match (GitLab row is now "bd sync only"). Confirm this is the intended workshop ship before merge:

```bash
jq -r '.mcpServers | keys[]' packs/workshop/overlay/.claude/settings.json | sort
```

If the intent is to ship a GitLab MCP server, add it to `settings.json` and revert the README edit.

---

## 6. `activites/` → `activities/` directory rename

Two parallel directory trees exist on this branch with mechanical doc content fixed in both:

- `activites/workshops/W2/gascity/step_0/packs/` (checkpoint tree — misspelled)
- `activites/labs/L2/gascity/step_0/packs/` (checkpoint tree — misspelled)
- `activities/workshops/` (curriculum deliverables tree — correctly spelled)
- `activities/labs/`, `activities/capstone/C1/` (same)

The rename was explicitly deferred to its own PR per the original migration plan's Principle 1 (shape preservation). When you're ready to rename:

1. Decide whether to move just the checkpoint trees, or to consolidate with the correctly-spelled `activities/` tree.
2. Update every reference: `rg -l 'activites/'`.
3. Update the curriculum files that refer to checkpoint paths.
4. Ship as a separate PR to keep the rename diff separable from the schema migration.

---

## 7. `my-factory/pack.toml.template` double-import of `packs/all`

The template imports `packs/all` at workspace scope (`[imports.all] source = "../packs/all"`) AND the sibling `city.toml.template` includes it at rig scope via `default_rig_includes`. This is intentional per `workshop:#786` — Gas City 0.15.x doesn't expose pack commands from rig-scoped imports, so the workspace-scope import surfaces `gc all wake-downstream` as a CLI command while the rig-scope import composes the 8 agents into each rig.

Verify the `workshop:#786` issue description still matches this claim before workshop handoff. If upstream fixes the gap, the workspace-scope import can be dropped.

---

## 8. Reference project README assumptions

`reference-project/fired-up-pizza/README.md` was updated to clarify that `gc rig add --include` only applies at first-time rig registration (not on re-runs), with a rig-scoped `[rigs.imports.<binding>]` pattern for post-registration pack changes. Review the "Adapting for Your Project" section to make sure the advice matches the rest of the curriculum.

---

## 9. Hit-count regeneration commands

The plan (`plans/fix-stale-docs.md`) cites specific hit counts for curriculum files. Those counts drift as the curriculum evolves. Always regenerate before acting on them:

```bash
# Per-file counts of phantom commands + [[agent]] teaching
rg -c 'gc watch|gc orchestrate|gc session stop|\[\[agent\]\]' curriculum/ -g '*.md'

# All curriculum files with mechanical-seeming hits (but which are teaching content)
rg -ln 'includes = \[|gc service restart' curriculum/ -g '*.md'
```

---

## 10. Verification the mechanical doc-fix pass passed

These greps should return 0 hits outside `plans/`, this file, and `curriculum/**` (which is flagged above for author rewrite, not mechanical fix):

```bash
rg -n 'gc poke' -g '*.md' -g '!plans/**' -g '!WORKSHOP_AUTHOR_NOTES.md' -g '!curriculum/**'
rg -n 'examples/actual/' -g '*.md' -g '!plans/**' -g '!WORKSHOP_AUTHOR_NOTES.md'
rg -n 'workshop\.default_rig_includes' -g '*.md' -g '!plans/**' -g '!WORKSHOP_AUTHOR_NOTES.md'
rg -n 'overlays/default' packs/ -g '*.md'
rg -n '\./scripts/sync-' -g '*.md' -g '!plans/**' -g '!WORKSHOP_AUTHOR_NOTES.md'
rg -n 'gc watch|gc orchestrate|gc session stop' -g '*.md' -g '!plans/**' -g '!WORKSHOP_AUTHOR_NOTES.md' -g '!curriculum/**'
rg -n 'gc service restart' -g '*.md' -g '!plans/**' -g '!WORKSHOP_AUTHOR_NOTES.md' -g '!curriculum/**'
```

Plus the full harness:

```bash
bash scripts/migration-check.sh
bash scripts/behavioral-smoke.sh
bash scripts/tutorial-check.sh
```
