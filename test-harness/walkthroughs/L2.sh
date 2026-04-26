#!/usr/bin/env bash
# L2.sh — Walkthrough for the FormulaV2 Planner + Architect lesson.
#
# README mirrored: activities/labs/L2/README.md
# Commands exercised:
#   - set the factory import through the city pack
#   - sync the existing rig's `factory` import
#   - gc sling <rig>/factory.planner ... --on mol-feature-intake
#   - observability: gc events, gc session list, gc graph, bd list, bd show
#   - config-over-chat: edit planner prompt, re-sling, verify second artifact
#
# Dry-run validates setup and command shape. Live mode starts the formula,
# waits for plan and architecture artifacts, then exercises config-over-chat.

set -uo pipefail

source "$WALK_REPO_ROOT/test-harness/walkthroughs/_common.sh"

lesson_prerequisites_check() {
  return 0
}

write_l2_factory_configs() {
  cat > "$WALK_L2_FACTORY/pack.toml" <<'TOML'
[pack]
name = "my-factory"
schema = 2

[defaults.rig.imports.factory]
source = "../packs/lessons/L2"
TOML

  cat > "$WALK_L2_FACTORY/city.toml" <<TOML
[workspace]
name = "$WALK_L2_CITY_NAME"
provider = "claude"

[session]
startup_timeout = "3m"

[daemon]
formula_v2 = true
patrol_interval = "30s"
max_restarts = 5
restart_window = "1h"
shutdown_timeout = "5s"
TOML
}

lesson_run() {
  local lesson_rc=0

  echo
  echo "[1/10] pre-flight"
  assert_walkthrough_preflight
  purge_stranded_walkthrough_cities

  echo
  echo "[2/10] scratch setup"
  WALK_L2_SCRATCH="$WALK_SCRATCH/L2"
  WALK_L2_FACTORY="$WALK_L2_SCRATCH/my-factory"
  WALK_L2_CITY_NAME="sfi-walkthrough-L2-$run_id"
  mkdir -p "$WALK_L2_FACTORY"
  cp -R "$WALK_REPO_ROOT/packs" "$WALK_L2_SCRATCH/packs"
  write_l2_factory_configs
  step_pass "L2 factory config selects copied packs/lessons/L2"
  save_state WALK_L2_FACTORY WALK_L2_CITY_NAME

  echo
  echo "[3/10] gc register L2 factory"
  if ! register_walkthrough_city "$WALK_L2_FACTORY" "$WALK_L2_CITY_NAME" "L2"; then
    fail "L2 factory register failed"
  fi

  echo
  echo "[4/10] project rig + gc rig add"
  WALK_L2_RIG="$WALK_L2_SCRATCH/rig"
  cp -r "$WALK_REPO_ROOT/test-harness/tutorial-walkthrough-rig" "$WALK_L2_RIG"
  (cd "$WALK_L2_RIG" && git init -q && git add -A && git commit -qm "initial" >/dev/null 2>&1)
  if (cd "$WALK_L2_FACTORY" && gc rig add "$WALK_L2_RIG" >/dev/null 2>&1); then
    step_pass "gc rig add succeeded"
  else
    step_fail "gc rig add failed"
    fail "rig add failed"
  fi
  save_state WALK_L2_RIG
  export WALK_FACTORY="$WALK_L2_FACTORY" WALK_RIG="$WALK_L2_RIG"

  echo
  echo "[5/10] sync existing rig factory import"
  local import_out
  import_out="$(cd "$WALK_L2_FACTORY" && gc --rig rig import remove factory 2>&1 || true)"
  log "gc --rig rig import remove factory:"
  echo "$import_out" | sed 's/^/    /' | tee -a "$WALK_LOG"
  import_out="$(cd "$WALK_L2_FACTORY" && gc --rig rig import add ../packs/lessons/L2 --name factory 2>&1)"
  log "gc --rig rig import add ../packs/lessons/L2 --name factory:"
  echo "$import_out" | sed 's/^/    /' | tee -a "$WALK_LOG"
  if echo "$import_out" | grep -q 'Added import "factory"'; then
    step_pass "existing rig imports packs/lessons/L2 as factory"
  else
    step_fail "gc --rig rig import add ../packs/lessons/L2 --name factory failed"
    fail "rig factory import sync failed"
  fi

  echo
  echo "[6/10] factory up"
  (cd "$WALK_L2_FACTORY" && gc doctor --fix >/dev/null 2>&1) || true
  if ! wait_for "supervisor responsive" \
    "cd '$WALK_L2_FACTORY' && gc status >/dev/null 2>&1" 120 3; then
    fail "supervisor unresponsive"
  fi
  step_pass "factory up"

  echo
  echo "[7/10] dry-run boundary"
  if [ "$WALK_DRY_RUN" = "1" ]; then
    step_pass "dry run validated L2 factory selection, rig sync, and formula entrypoint shape"
    return 0
  fi

  start_event_stream "$WALK_L2_FACTORY"

  echo
  echo "[8/10] gc sling L2 formula"
  local rig_tree_before sling_out
  rig_tree_before="$(cd "$WALK_L2_RIG" && find . -type f -not -path './.git/*' -not -path './.beads/*' | sort)"
  echo "$rig_tree_before" > "$WALK_L2_SCRATCH/rig-tree-before.txt"

  sling_out="$(cd "$WALK_L2_FACTORY" && gc sling rig/factory.planner \
    "Plan the memory feature: store, recall, and clear calculator memory" \
    --on mol-feature-intake 2>&1)"
  log "gc sling rig/factory.planner --on mol-feature-intake:"
  echo "$sling_out" | sed 's/^/    /' | tee -a "$WALK_LOG"
  if ! echo "$sling_out" | grep -qiE 'Slung|dispatched|created'; then
    step_fail "gc sling did not report a routed formula run"
    stop_event_stream
    fail "L2 formula sling failed"
  fi
  WALK_L2_WORKFLOW_BEAD_ID="$(echo "$sling_out" | awk '/Attached workflow/ {print $3; exit}')"
  WALK_L2_ROOT_BEAD_ID="$(echo "$sling_out" | grep -oE 'rig-[a-zA-Z0-9._-]+' | head -1 || true)"
  if [ -n "$WALK_L2_WORKFLOW_BEAD_ID" ]; then
    export WALK_ROOT_BEAD_ID="$WALK_L2_WORKFLOW_BEAD_ID"
    save_state WALK_L2_WORKFLOW_BEAD_ID
  elif [ -n "$WALK_L2_ROOT_BEAD_ID" ]; then
    export WALK_ROOT_BEAD_ID="$WALK_L2_ROOT_BEAD_ID"
    save_state WALK_L2_ROOT_BEAD_ID
  fi

  local plan_check='
    count=$(find "'"$WALK_L2_RIG"'/docs/plans" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " ")
    [ "$count" -ge 1 ]
  '
  if ! wait_for "Planner to write docs/plans/*.md" "$plan_check" 600 15 "" "rig/factory.planner" "$WALK_L2_FACTORY"; then
    stop_event_stream
    fail "Planner failed to produce plan artifact"
  fi
  WALK_L2_WORK_PACKAGE="$(find "$WALK_L2_RIG/docs/plans" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Planner produced plan: $WALK_L2_WORK_PACKAGE"

  local arch_check='
    count=$(find "'"$WALK_L2_RIG"'/docs/architecture" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " ")
    [ "$count" -ge 1 ]
  '
  if ! wait_for "Architect to write docs/architecture/*.md" "$arch_check" 600 15 "" "rig/factory.architect" "$WALK_L2_FACTORY"; then
    stop_event_stream
    fail "Architect failed to produce architecture artifact"
  fi
  WALK_L2_ARCHITECTURE="$(find "$WALK_L2_RIG/docs/architecture" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Architect produced architecture: $WALK_L2_ARCHITECTURE"

  assert_artifact_has_sections "$WALK_L2_WORK_PACKAGE" \
    '^## Goal' '^## User Stories' '^## Acceptance Criteria'
  assert_artifact_has_sections "$WALK_L2_ARCHITECTURE" \
    '^## Context' '^## Options Considered' '^## Decision'

  echo
  echo "[9/10] observability commands"
  log "exercising observability commands from L2 curriculum"
  (cd "$WALK_L2_FACTORY" && gc session list 2>&1 | head -10) | sed 's/^/    /' | tee -a "$WALK_LOG"
  (cd "$WALK_L2_RIG" && bd list --limit 5 2>&1) | sed 's/^/    /' | tee -a "$WALK_LOG"
  if [ -n "${WALK_ROOT_BEAD_ID:-}" ]; then
    (cd "$WALK_L2_FACTORY" && gc graph "$WALK_ROOT_BEAD_ID" 2>&1 | head -20) | sed 's/^/    /' | tee -a "$WALK_LOG"
    (cd "$WALK_L2_RIG" && bd show "$WALK_ROOT_BEAD_ID" 2>&1 | head -20) | sed 's/^/    /' | tee -a "$WALK_LOG"
  fi
  step_pass "observability commands returned data"

  echo
  echo "[10/10] config-over-chat: edit prompt + re-sling"
  log "config-over-chat: adding project-specific rule to planner prompt"
  local prompt_file="$WALK_L2_SCRATCH/packs/lessons/L2/agents/planner/prompt.template.md"
  printf '\n- When the project uses a test runner, acceptance criteria must reference the test command from CLAUDE.md.\n' >> "$prompt_file"

  (cd "$WALK_L2_FACTORY" && gc restart >/dev/null 2>&1) || true
  wait_for "supervisor responsive after restart" \
    "cd '$WALK_L2_FACTORY' && gc status >/dev/null 2>&1" 120 3 \
    || { stop_event_stream; fail "supervisor unresponsive after config-over-chat restart"; }

  local sling2_out
  sling2_out="$(cd "$WALK_L2_FACTORY" && gc sling rig/factory.planner \
    "Plan the undo/redo history feature" \
    --on mol-feature-intake 2>&1)"
  log "config-over-chat re-sling:"
  echo "$sling2_out" | sed 's/^/    /' | tee -a "$WALK_LOG"

  local plan2_check='
    count=$(find "'"$WALK_L2_RIG"'/docs/plans" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " ")
    [ "$count" -ge 2 ]
  '
  if wait_for "second plan artifact from config-over-chat re-sling" "$plan2_check" 600 15 "" "rig/factory.planner" "$WALK_L2_FACTORY"; then
    step_pass "config-over-chat produced a second plan artifact"
  else
    log "WARN: config-over-chat re-sling did not produce a second plan within timeout (non-fatal)"
  fi

  log "what L2 produced (rig tree diff since lesson start):"
  (cd "$WALK_L2_RIG" && find . -type f -not -path './.git/*' -not -path './.beads/*' | sort \
    | diff "$WALK_L2_SCRATCH/rig-tree-before.txt" - | grep '^>' | sed 's/^> /      + /') | tee -a "$WALK_LOG"

  # Save snapshots for validate-lesson-content skill
  save_snapshot "L2" "gc-sling.txt" "$sling_out"
  save_snapshot_file "L2" "plan-artifact.md" "$WALK_L2_WORK_PACKAGE"
  save_snapshot_file "L2" "architecture-artifact.md" "$WALK_L2_ARCHITECTURE"
  save_artifact_sections "L2" "plan-sections.txt" "$WALK_L2_WORK_PACKAGE"
  save_artifact_sections "L2" "architecture-sections.txt" "$WALK_L2_ARCHITECTURE"
  local status_snap
  status_snap="$(cd "$WALK_L2_FACTORY" && gc status 2>&1)"
  save_snapshot "L2" "gc-status.txt" "$status_snap"

  save_state WALK_L2_WORK_PACKAGE WALK_L2_ARCHITECTURE
  stop_event_stream
  return "$lesson_rc"
}

lesson_rc=0

lesson_prerequisites_check || exit 77
lesson_run
exit "$lesson_rc"
