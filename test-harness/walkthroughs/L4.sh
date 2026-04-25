#!/usr/bin/env bash
# L4.sh — FormulaV2 walkthrough for the delivery-review factory.

set -uo pipefail

source "$WALK_REPO_ROOT/test-harness/walkthroughs/_common.sh"

lesson_prerequisites_check() {
  if ! command -v node >/dev/null 2>&1; then
    echo "L4: node not on PATH" >&2
    return 1
  fi
  local node_major
  node_major="$(node -v | sed -E 's/^v([0-9]+).*/\1/')"
  if [ "${node_major:-0}" -lt 18 ]; then
    echo "L4: node $node_major too old (need 18+)" >&2
    return 1
  fi
  return 0
}

write_l4_factory_configs() {
  cat > "$WALK_L4_FACTORY/pack.toml" <<'TOML'
[pack]
name = "my-factory"
schema = 2

[defaults.rig.imports.factory]
source = "../packs/lessons/L4"
TOML

  cat > "$WALK_L4_FACTORY/city.toml" <<TOML
[workspace]
name = "$WALK_L4_CITY_NAME"
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
  echo "[1/9] pre-flight"
  assert_walkthrough_preflight
  purge_stranded_walkthrough_cities

  echo
  echo "[2/9] scratch setup"
  WALK_L4_SCRATCH="$WALK_SCRATCH/L4"
  WALK_L4_FACTORY="$WALK_L4_SCRATCH/my-factory"
  WALK_L4_CITY_NAME="sfi-walkthrough-L4-$run_id"
  mkdir -p "$WALK_L4_FACTORY"
  cp -R "$WALK_REPO_ROOT/packs" "$WALK_L4_SCRATCH/packs"
  write_l4_factory_configs
  step_pass "L4 factory config selects copied packs/lessons/L4"
  save_state WALK_L4_FACTORY WALK_L4_CITY_NAME

  echo
  echo "[3/9] gc register L4 factory"
  if ! register_walkthrough_city "$WALK_L4_FACTORY" "$WALK_L4_CITY_NAME" "L4"; then
    fail "L4 factory register failed"
  fi

  echo
  echo "[4/9] project rig + gc rig add"
  WALK_L4_RIG="$WALK_L4_SCRATCH/rig"
  cp -r "$WALK_REPO_ROOT/test-harness/tutorial-walkthrough-rig" "$WALK_L4_RIG"
  (
    cd "$WALK_L4_RIG" \
      && git init -q \
      && git config user.name "Factory Harness" \
      && git config user.email "factory@example.local" \
      && git add -A \
      && git commit -qm "initial" >/dev/null 2>&1
  )
  if (cd "$WALK_L4_FACTORY" && gc rig add "$WALK_L4_RIG" >/dev/null 2>&1); then
    step_pass "gc rig add succeeded"
  else
    step_fail "gc rig add failed"
    fail "rig add failed"
  fi
  local build_baseline_sha
  build_baseline_sha="$(cd "$WALK_L4_RIG" && git rev-parse HEAD)"
  save_state WALK_L4_RIG
  export WALK_FACTORY="$WALK_L4_FACTORY" WALK_RIG="$WALK_L4_RIG"

  echo
  echo "[5/9] sync existing rig factory import"
  local import_out
  import_out="$(cd "$WALK_L4_FACTORY" && gc --rig rig import remove factory 2>&1 || true)"
  log "gc --rig rig import remove factory:"
  echo "$import_out" | sed 's/^/    /' | tee -a "$WALK_LOG"
  import_out="$(cd "$WALK_L4_FACTORY" && gc --rig rig import add ../packs/lessons/L4 --name factory 2>&1)"
  log "gc --rig rig import add ../packs/lessons/L4 --name factory:"
  echo "$import_out" | sed 's/^/    /' | tee -a "$WALK_LOG"
  if echo "$import_out" | grep -q 'Added import "factory"'; then
    step_pass "existing rig imports packs/lessons/L4 as factory"
  else
    step_fail "gc --rig rig import add ../packs/lessons/L4 --name factory failed"
    fail "rig factory import sync failed"
  fi

  echo
  echo "[6/9] factory up"
  (cd "$WALK_L4_FACTORY" && gc doctor --fix >/dev/null 2>&1) || true
  if ! wait_for "supervisor responsive" \
    "cd '$WALK_L4_FACTORY' && gc status >/dev/null 2>&1" 120 3; then
    fail "supervisor unresponsive"
  fi
  step_pass "factory up"

  echo
  echo "[7/9] dry-run boundary"
  if [ "$WALK_DRY_RUN" = "1" ]; then
    step_pass "dry run validated L4 factory selection, rig sync, and formula entrypoint shape"
    return 0
  fi

  start_event_stream "$WALK_L4_FACTORY"

  echo
  echo "[8/9] gc sling L4 formula"
  local rig_tree_before sling_out
  rig_tree_before="$(cd "$WALK_L4_RIG" && find . -type f -not -path './.git/*' -not -path './.beads/*' | sort)"
  echo "$rig_tree_before" > "$WALK_L4_SCRATCH/rig-tree-before.txt"

  sling_out="$(cd "$WALK_L4_FACTORY" && gc sling rig/factory.planner \
    "Add a clamp operation: clamp(x, lo, hi) returns x bounded to [lo, hi]" \
    --on mol-delivery-review 2>&1)"
  log "gc sling rig/factory.planner --on mol-delivery-review:"
  echo "$sling_out" | sed 's/^/    /' | tee -a "$WALK_LOG"
  if ! echo "$sling_out" | grep -qiE 'Slung|dispatched|created'; then
    step_fail "gc sling did not report a routed formula run"
    stop_event_stream
    fail "L4 formula sling failed"
  fi
  WALK_L4_WORKFLOW_BEAD_ID="$(echo "$sling_out" | awk '/Attached workflow/ {print $3; exit}')"
  if [ -n "$WALK_L4_WORKFLOW_BEAD_ID" ]; then
    export WALK_ROOT_BEAD_ID="$WALK_L4_WORKFLOW_BEAD_ID"
    save_state WALK_L4_WORKFLOW_BEAD_ID
  fi

  local plan_check='count=$(find "'"$WALK_L4_RIG"'/docs/plans" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " "); [ "$count" -ge 1 ]'
  wait_for "Planner to write docs/plans/*.md" "$plan_check" 600 15 "" "rig/factory.planner" "$WALK_L4_FACTORY" \
    || { stop_event_stream; fail "Planner failed to produce plan artifact"; }
  WALK_L4_PLAN="$(find "$WALK_L4_RIG/docs/plans" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Planner produced plan: $WALK_L4_PLAN"

  local arch_check='count=$(find "'"$WALK_L4_RIG"'/docs/architecture" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " "); [ "$count" -ge 1 ]'
  wait_for "Architect to write docs/architecture/*.md" "$arch_check" 600 15 "" "rig/factory.architect" "$WALK_L4_FACTORY" \
    || { stop_event_stream; fail "Architect failed to produce architecture artifact"; }
  WALK_L4_ARCHITECTURE="$(find "$WALK_L4_RIG/docs/architecture" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Architect produced architecture: $WALK_L4_ARCHITECTURE"

  local design_check='count=$(find "'"$WALK_L4_RIG"'/docs/designs" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " "); [ "$count" -ge 1 ]'
  wait_for "Designer to write docs/designs/*.md" "$design_check" 600 15 "" "rig/factory.designer" "$WALK_L4_FACTORY" \
    || { stop_event_stream; fail "Designer failed to produce design artifact"; }
  WALK_L4_DESIGN="$(find "$WALK_L4_RIG/docs/designs" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Designer produced design: $WALK_L4_DESIGN"

  local build_check='cd "'"$WALK_L4_RIG"'" && git log --all --not "'"$build_baseline_sha"'" --oneline 2>/dev/null | grep -q .'
  wait_for "Builder to commit at least one new change" "$build_check" 900 20 "" "rig/factory.builder" "$WALK_L4_FACTORY" \
    || { stop_event_stream; fail "Builder did not produce a new commit"; }
  WALK_L4_CODE_COMMITTED="$(cd "$WALK_L4_RIG" && git log --all --oneline | head -1)"
  step_pass "Builder committed: $WALK_L4_CODE_COMMITTED"

  local review_check='count=$(find "'"$WALK_L4_RIG"'/docs/reviews" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " "); [ "$count" -ge 1 ]'
  wait_for "Reviewer to write docs/reviews/*.md" "$review_check" 600 15 "" "rig/factory.reviewer" "$WALK_L4_FACTORY" \
    || { stop_event_stream; fail "Reviewer failed to produce review artifact"; }
  WALK_L4_REVIEW="$(find "$WALK_L4_RIG/docs/reviews" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Reviewer produced review: $WALK_L4_REVIEW"

  local release_check='count=$(find "'"$WALK_L4_RIG"'/docs/releases" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " "); [ "$count" -ge 1 ]'
  wait_for "Release gate to write docs/releases/*.md" "$release_check" 600 15 "" "rig/factory.release-gate" "$WALK_L4_FACTORY" \
    || { stop_event_stream; fail "Release gate failed to produce release artifact"; }
  WALK_L4_RELEASE="$(find "$WALK_L4_RIG/docs/releases" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Release gate produced release record: $WALK_L4_RELEASE"

  echo
  echo "[9/9] verify artifacts and tests"
  local builder_branch test_out test_rc
  builder_branch="$(cd "$WALK_L4_RIG" && git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads/ | head -1)"
  (cd "$WALK_L4_RIG" && git checkout -q "$builder_branch" 2>&1) | sed 's/^/    /' | tee -a "$WALK_LOG" || true
  test_out="$(cd "$WALK_L4_RIG" && node --test 2>&1)"; test_rc=$?
  log "node --test output (last 20 lines):"
  echo "$test_out" | tail -20 | sed 's/^/    /' | tee -a "$WALK_LOG"
  if [ "$test_rc" -eq 0 ]; then
    step_pass "node --test passes on $builder_branch"
  else
    stop_event_stream
    fail "node --test failed on $builder_branch"
  fi
  if grep -R "clamp" "$WALK_L4_RIG/src" "$WALK_L4_RIG/test" >/dev/null 2>&1; then
    step_pass "implementation references clamp in source or tests"
  else
    stop_event_stream
    fail "builder commit did not implement the requested clamp feature"
  fi

  assert_artifact_has_sections "$WALK_L4_PLAN" \
    '^## Goal' '^## User Stories' '^## Acceptance Criteria'
  assert_artifact_has_sections "$WALK_L4_ARCHITECTURE" \
    '^## Context' '^## Options Considered' '^## Decision'
  assert_artifact_has_sections "$WALK_L4_DESIGN" \
    '^## Interface' '^## Behavior' '^## Edge Cases' '^## Test Plan'
  assert_artifact_has_sections "$WALK_L4_REVIEW" \
    '^## Verdict' '^## Findings' '^## Test Evidence'
  assert_file_contains_at_least "$WALK_L4_REVIEW" 1 \
    "review report: severity-labelled finding" '\b(critical|high|medium|low)\b'
  assert_artifact_has_sections "$WALK_L4_RELEASE" \
    '^## Verdict' '^## Required Checks' '^## Evidence'
  assert_file_contains_at_least "$WALK_L4_RELEASE" 1 \
    "release gate: explicit PASS/FAIL verdict" '\b(PASS|FAIL)\b'

  log "what L4 produced (rig tree diff since lesson start):"
  (cd "$WALK_L4_RIG" && find . -type f -not -path './.git/*' -not -path './.beads/*' | sort \
    | diff "$WALK_L4_SCRATCH/rig-tree-before.txt" - | grep '^>' | sed 's/^> /      + /') | tee -a "$WALK_LOG"

  save_state WALK_L4_PLAN WALK_L4_ARCHITECTURE WALK_L4_DESIGN WALK_L4_CODE_COMMITTED WALK_L4_REVIEW WALK_L4_RELEASE
  stop_event_stream
  return "$lesson_rc"
}

lesson_rc=0

lesson_prerequisites_check || exit 77
lesson_run
exit "$lesson_rc"
