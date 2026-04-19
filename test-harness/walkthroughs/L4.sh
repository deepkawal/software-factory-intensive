#!/usr/bin/env bash
# L4.sh — Walkthrough for activities/labs/L4/README.md
#         (Reviewer + Release-Gate handoff on top of a Builder commit).
#
# README mirrored:   activities/labs/L4/README.md
# Pipeline chained:  Planner → Architect → Designer → Builder → Reviewer → Release-Gate
# Commands exercised: bd create --label needs-plan, then explicit slings
#                     through all six stages.
# Prerequisites:      none — self-contained fresh factory (same reason as L2/L3)
# Produces:           WALK_L4_*: work-package, ADR, design spec, Builder commit,
#                     review report, release-gate decision.
# Expected runtime:   ~30-45 min live (6 LLM stages + factory bootstrap)
# Live-agent stages:  Planner/Architect/Designer/Builder (same as L3) +
#                     Reviewer writes review-reports/*.md +
#                     Release-Gate writes release-gates/*.md (PASS/FAIL).
#
# Success criterion: all six artifacts materialize. Reviewer's report has
# at least one severity-labelled finding. Release-Gate's output contains
# an explicit PASS or FAIL verdict.
#
# KNOWN BLOCKER (as of gc 0.15.2): `gc rig add` fails immediately after
# `gc register` with "could not acquire dolt start lock". This affects all
# lab walkthroughs, not just L4. See WORKSHOP_AUTHOR_NOTES.md §13 for
# context. When the upstream fix lands, this walkthrough runs end-to-end
# unmodified.

set -uo pipefail

source "$WALK_REPO_ROOT/test-harness/walkthroughs/_common.sh"

# --- prerequisites check ----------------------------------------------

lesson_prerequisites_check() {
  if ! command -v node >/dev/null 2>&1; then
    echo "L4: node not on PATH — Builder's tests need 'node --test'" >&2
    return 1
  fi
  local node_major
  node_major="$(node -v | sed -E 's/^v([0-9]+).*/\1/')"
  if [ "${node_major:-0}" -lt 18 ]; then
    echo "L4: node $node_major too old (need 18+ for node:test)" >&2
    return 1
  fi
  return 0
}

# --- body -------------------------------------------------------------

lesson_run() {
  local lesson_rc=0

  echo
  echo "[1/14] pre-flight"
  assert_walkthrough_preflight
  [ "$lesson_rc" -ne 0 ] && fail "pre-flight failed"
  purge_stranded_walkthrough_cities

  echo
  echo "[2/14] scratch setup"
  WALK_L4_SCRATCH="$WALK_SCRATCH/L4"
  export TMUX_TMPDIR="$WALK_L4_SCRATCH/tmux"
  mkdir -p "$TMUX_TMPDIR"
  unset GC_SESSION GC_BEADS GC_DOLT 2>/dev/null || true
  step_pass "scratch tree $WALK_L4_SCRATCH"

  echo
  echo "[3/14] copy my-factory templates"
  WALK_L4_FACTORY="$WALK_L4_SCRATCH/my-factory"
  mkdir -p "$WALK_L4_FACTORY"
  cp "$WALK_REPO_ROOT/my-factory/pack.toml.template" "$WALK_L4_FACTORY/pack.toml"
  cp "$WALK_REPO_ROOT/my-factory/city.toml.template" "$WALK_L4_FACTORY/city.toml"
  ln -s "$WALK_REPO_ROOT/packs" "$WALK_L4_SCRATCH/packs"
  step_pass "templates copied + packs symlinked"
  save_state WALK_L4_FACTORY

  echo
  echo "[4/14] gc register L4 factory"
  WALK_L4_CITY_NAME="sfi-walkthrough-L4-$run_id"
  local register_out
  register_out="$(cd "$WALK_L4_FACTORY" && gc register --name "$WALK_L4_CITY_NAME" . 2>&1)"
  if echo "$register_out" | grep -q "Registered city '$WALK_L4_CITY_NAME'"; then
    REGISTERED_CITY_PATHS+=("$WALK_L4_FACTORY")
    step_pass "registered $WALK_L4_CITY_NAME"
  else
    step_fail "gc register did not emit 'Registered city' marker"
    echo "$register_out" | head -10 | sed 's/^/    /' | tee -a "$WALK_LOG"
    fail "L4 factory register failed"
  fi
  save_state WALK_L4_CITY_NAME

  echo
  echo "[5/14] bundled rig + gc rig add"
  WALK_L4_RIG="$WALK_L4_SCRATCH/rig"
  cp -r "$WALK_REPO_ROOT/test-harness/tutorial-walkthrough-rig" "$WALK_L4_RIG"
  (cd "$WALK_L4_RIG" && git init -q && git add -A && git commit -qm "initial" >/dev/null 2>&1)
  local initial_sha
  initial_sha="$(cd "$WALK_L4_RIG" && git rev-parse HEAD)"
  step_pass "bundled rig at $WALK_L4_RIG (initial SHA $initial_sha)"

  if (cd "$WALK_L4_FACTORY" && gc rig add "$WALK_L4_RIG" >/dev/null 2>&1); then
    step_pass "gc rig add succeeded"
  else
    step_fail "gc rig add failed"
    fail "rig add failed"
  fi
  (cd "$WALK_L4_RIG" && bd config set types.custom "convoy") >/dev/null 2>&1 || true
  save_state WALK_L4_RIG

  echo
  echo "[6/14] factory up"
  (cd "$WALK_L4_FACTORY" && gc doctor --fix >/dev/null 2>&1) || true
  if ! wait_for "supervisor responsive" \
    "cd '$WALK_L4_FACTORY' && gc status >/dev/null 2>&1" 120 3; then
    fail "supervisor unresponsive"
  fi
  local agents_needed=(architect planner designer builder reviewer validator release-gate improver)
  local agent_pattern="${agents_needed[*]}"
  agent_pattern="${agent_pattern// /|}"
  if ! wait_for "all 8 agents visible in gc status" \
    "cd '$WALK_L4_FACTORY' && gc status 2>/dev/null | grep -cE '($agent_pattern)' | awk '{exit (\$1 >= 8 ? 0 : 1)}'" \
    120 4; then
    divergence "$WALK_LESSON_NAME" "fewer than 8 agents visible — proceeding"
  fi
  step_pass "factory up"
  start_event_stream "$WALK_L4_FACTORY"

  echo
  echo "[7/14] bd create (needs-plan)"
  if [ "$WALK_DRY_RUN" = "1" ]; then
    step_pass "dry run — skipping live-agent work"
    stop_event_stream
    return 0
  fi

  local bead_out
  bead_out="$(cd "$WALK_L4_RIG" && bd create \
    --title "Add a clamp operation (clamp(x, lo, hi) returns x bounded to [lo,hi])" \
    --label needs-plan 2>&1)"
  log "bd create output:"
  echo "$bead_out" | sed 's/^/    /' | tee -a "$WALK_LOG"

  WALK_L4_BEAD_ID="$(echo "$bead_out" | grep -oE 'rig-[a-zA-Z0-9.]+' | head -1)"
  if [ -z "$WALK_L4_BEAD_ID" ]; then
    step_fail "could not extract bead id"
    stop_event_stream
    fail "bd create unparsable"
  fi
  step_pass "filed bead $WALK_L4_BEAD_ID"
  save_state WALK_L4_BEAD_ID

  # Pipeline-stage helper: fresh bead per agent via stage_bead_create,
  # then sling --nudge. Mirrors the activity README verbatim.
  STAGE_BEAD=""
  _stage() {
    local stage_name="$1" label="$2" target="$3" artifact_dir="$4" upstream="$5" budget="${6:-900}"
    local stage_title="$stage_name: clamp operation"
    STAGE_BEAD=""
    log "[$stage_name] bd create --labels $label  (chains after $upstream)"
    local bead
    bead="$(stage_bead_create "$WALK_L4_RIG" "$stage_title" "$label" "$upstream")" || {
      step_fail "bd create failed for $stage_name"; return 1
    }
    STAGE_BEAD="$bead"
    log "[$stage_name] → $STAGE_BEAD"
    if ! wait_for_agent_ready "$WALK_L4_FACTORY" "$target" 180 5; then
      step_fail "$stage_name session tmux never came live"; return 1
    fi
    sling_and_nudge "$WALK_L4_FACTORY" "$target" "$STAGE_BEAD"
    if [ "$SLING_RC" -ne 0 ]; then
      step_fail "sling to $target produced no success marker"; return 1
    fi
    local check='
      count=$(find "'"$WALK_L4_RIG"'/'"$artifact_dir"'" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " ")
      [ "$count" -ge 1 ]
    '
    local rescue="rescue_dead_session '$WALK_L4_RIG' '$STAGE_BEAD' '$target'"
    if ! wait_for "$stage_name to write $artifact_dir/*.md" "$check" "$budget" 15 "$rescue"; then
      log "debugging — session list:"
      (cd "$WALK_L4_FACTORY" && gc session list 2>/dev/null | head -12 | sed 's/^/    /') | tee -a "$WALK_LOG"
      return 1
    fi
    return 0
  }

  echo
  echo "[8/14] Planner stage"
  if ! wait_for_agent_ready "$WALK_L4_FACTORY" rig/planner.planner 180 5; then
    step_fail "Planner session tmux never came live"
    stop_event_stream; fail "Planner session not ready"
  fi
  sling_and_nudge "$WALK_L4_FACTORY" rig/planner.planner "$WALK_L4_BEAD_ID"
  if [ "$SLING_RC" -ne 0 ]; then
    step_fail "sling to Planner produced no success marker"
    stop_event_stream; fail "Planner sling failed"
  fi
  local planner_check='
    count=$(find "'"$WALK_L4_RIG"'/work-packages" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " ")
    [ "$count" -ge 1 ]
  '
  if ! wait_for "Planner to write work-packages/*.md" "$planner_check" 600 15; then
    stop_event_stream; fail "Planner stage failed"
  fi
  WALK_L4_WORK_PACKAGE="$(find "$WALK_L4_RIG/work-packages" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Planner → $(basename "$WALK_L4_WORK_PACKAGE")"

  echo
  echo "[9/14] Architect stage"
  _stage Architect needs-architecture rig/architect.architect docs/adr "$WALK_L4_BEAD_ID" 900 || {
    stop_event_stream; fail "Architect stage failed"
  }
  local arch_bead="$STAGE_BEAD"
  WALK_L4_ADR="$(find "$WALK_L4_RIG/docs/adr" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Architect → $(basename "$WALK_L4_ADR")"

  echo
  echo "[10/14] Designer stage"
  _stage Designer needs-design rig/designer.designer docs/design "$arch_bead" 900 || {
    stop_event_stream; fail "Designer stage failed"
  }
  local design_bead="$STAGE_BEAD"
  WALK_L4_DESIGN_SPEC="$(find "$WALK_L4_RIG/docs/design" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Designer → $(basename "$WALK_L4_DESIGN_SPEC")"

  echo
  echo "[11/14] Builder stage — code + tests"
  local build_bead
  build_bead="$(stage_bead_create "$WALK_L4_RIG" "Build: clamp operation" ready-to-build "$design_bead")" || {
    step_fail "bd create failed for Builder"
    stop_event_stream; fail "Builder bead creation failed"
  }
  log "[Builder] → $build_bead"
  if ! wait_for_agent_ready "$WALK_L4_FACTORY" rig/builder.builder 180 5; then
    step_fail "Builder session tmux never came live"
    stop_event_stream; fail "Builder session not ready"
  fi
  sling_and_nudge "$WALK_L4_FACTORY" rig/builder.builder "$build_bead"
  if [ "$SLING_RC" -ne 0 ]; then
    step_fail "sling to Builder produced no success marker"
    stop_event_stream; fail "Builder sling failed"
  fi
  local initial_hash
  initial_hash="$(cd "$WALK_L4_RIG" && git log --oneline -1 "$initial_sha" 2>/dev/null | awk '{print $1}')"
  local build_check='
    cd "'"$WALK_L4_RIG"'" && git log --all --oneline 2>/dev/null | grep -v "'"$initial_hash"'" | grep -q .
  '
  if ! wait_for "Builder to commit at least one new change" "$build_check" 900 20; then
    step_fail "Builder did not produce a new commit within 15min"
    stop_event_stream; fail "Builder stage failed"
  fi
  WALK_L4_CODE_COMMITTED="$(cd "$WALK_L4_RIG" && git log --all --oneline | head -1)"
  step_pass "Builder committed: $WALK_L4_CODE_COMMITTED"

  echo
  echo "[12/14] Reviewer stage"
  _stage Reviewer needs-review rig/reviewer.reviewer review-reports "$build_bead" 600 || {
    stop_event_stream; fail "Reviewer stage failed"
  }
  local review_bead="$STAGE_BEAD"
  WALK_L4_REVIEW_REPORT="$(find "$WALK_L4_RIG/review-reports" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Reviewer → $(basename "$WALK_L4_REVIEW_REPORT")"

  echo
  echo "[13/14] Release-Gate stage"
  _stage Release-Gate ready-to-ship rig/release-gate.release-gate release-gates "$review_bead" 600 || {
    stop_event_stream; fail "Release-Gate stage failed"
  }
  WALK_L4_RELEASE_GATE="$(find "$WALK_L4_RIG/release-gates" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Release-Gate → $(basename "$WALK_L4_RELEASE_GATE")"

  echo
  echo "[14/14] verify artifacts"
  # Structural checks. Reviewer report should mention at least one severity
  # tier. Release gate should contain a PASS or FAIL verdict.
  if [ -n "$WALK_L4_REVIEW_REPORT" ]; then
    if grep -iqE '(severity|critical|high|medium|low|finding)' "$WALK_L4_REVIEW_REPORT"; then
      step_pass "review report mentions severity/findings"
    else
      divergence "$WALK_LESSON_NAME" "review report has no severity/finding markers"
    fi
  fi
  if [ -n "$WALK_L4_RELEASE_GATE" ]; then
    if grep -iqE '\b(PASS|FAIL|approve|reject|blocked|ship|no-ship)\b' "$WALK_L4_RELEASE_GATE"; then
      step_pass "release gate has explicit verdict"
    else
      divergence "$WALK_LESSON_NAME" "release gate has no PASS/FAIL verdict"
    fi
  fi

  # Same content-shape checks as L3 for the upstream artifacts.
  [ -n "$WALK_L4_WORK_PACKAGE" ] && assert_artifact_has_sections "$WALK_L4_WORK_PACKAGE" \
    '^## (user story|acceptance criteria|overview|problem|goals?|scope)'
  [ -n "$WALK_L4_ADR" ] && assert_artifact_has_sections "$WALK_L4_ADR" \
    '^## context' '^## (options|decision)'
  [ -n "$WALK_L4_DESIGN_SPEC" ] && assert_artifact_has_sections "$WALK_L4_DESIGN_SPEC" \
    '^## (interface|props|interactions|edge cases|test plan|components|behavior)'

  save_state WALK_L4_WORK_PACKAGE WALK_L4_ADR WALK_L4_DESIGN_SPEC \
             WALK_L4_CODE_COMMITTED WALK_L4_REVIEW_REPORT WALK_L4_RELEASE_GATE
  step_pass "L4: Planner → Architect → Designer → Builder → Reviewer → Release-Gate complete"

  stop_event_stream
  return "$lesson_rc"
}

# --- main -------------------------------------------------------------

lesson_rc=0

lesson_prerequisites_check || exit 77
lesson_run
exit "$lesson_rc"
