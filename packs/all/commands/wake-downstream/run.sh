#!/bin/sh
# wake-downstream — Check if any labelled beads just became ready and
# sling them to the appropriate agent. Called from each agent's formula
# handoff step via `gc all wake-downstream &` after `bd close`. Runs in
# the background to avoid blocking the closing agent.
#
# Invoked as a pack command (gc <binding> <cmd>) because Gas City 0.15.x
# does not expose $PACK_DIR in agent session shells — a relative path
# like `sh packs/all/assets/wake-downstream.sh` would be topology-coupled.
# See workshop:#785 and the migration plan §Formula handoff rewrite.

set -e

GC_BIN="${GC_BIN:-gc}"

wake_agent() {
  local label="$1" agent="$2"
  local bead_id
  bead_id=$(bd ready --label="$label" --limit=1 --json 2>/dev/null \
    | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4) || true
  if [ -n "$bead_id" ]; then
    "$GC_BIN" sling "$agent" "$bead_id" --nudge >/dev/null 2>&1 || true
  fi
}

wake_agent needs-architecture architect
wake_agent needs-plan planner
wake_agent needs-design designer
wake_agent needs-tests validator
wake_agent ready-to-build builder
wake_agent needs-review reviewer
wake_agent ready-to-ship release-gate
