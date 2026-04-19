#!/usr/bin/env bash
# L3.sh — Walkthrough for activities/labs/L3/README.md (Designer + Builder handoff).
#
# README mirrored:   activities/labs/L3/README.md
# Pipeline chained:  Planner → Architect → Designer → Builder
# Commands exercised: bd create --label needs-plan, then explicit slings
#                     to each agent in sequence.
# Prerequisites:      none — self-contained fresh factory
# Produces:           WALK_L3_BEAD_ID, WALK_L3_WORK_PACKAGE, WALK_L3_ADR,
#                     WALK_L3_DESIGN_SPEC, WALK_L3_CODE_COMMITTED
# Expected runtime:   ~20-30 min live (4 LLM stages + factory bootstrap)
# Live-agent stages:  Planner writes work-package; Architect writes ADR;
#                     Designer writes design spec; Builder commits code
#                     to feature branch + updates/adds tests.
#
# Success criterion: all four artifacts materialize AND the Builder
# committed at least one new file under src/ on a feature branch.
# We run `node --test` after the run to confirm the Builder's tests
# actually pass — a "builder hallucinated tests" failure wouldn't
# show up in artifact-existence checks.

set -uo pipefail

source "$WALK_REPO_ROOT/test-harness/walkthroughs/_common.sh"

# --- prerequisites check ----------------------------------------------

lesson_prerequisites_check() {
  if ! command -v node >/dev/null 2>&1; then
    echo "L3: node not on PATH — Builder's tests need 'node --test'" >&2
    return 1
  fi
  # Node 18+ ships node:test built-in. Older versions won't work.
  local node_major
  node_major="$(node -v | sed -E 's/^v([0-9]+).*/\1/')"
  if [ "${node_major:-0}" -lt 18 ]; then
    echo "L3: node $node_major too old (need 18+ for node:test)" >&2
    return 1
  fi
  return 0
}

# --- body -------------------------------------------------------------

lesson_run() {
  local lesson_rc=0

  echo
  echo "[1/12] pre-flight"
  assert_walkthrough_preflight
  [ "$lesson_rc" -ne 0 ] && fail "pre-flight failed"
  purge_stranded_walkthrough_cities

  echo
  echo "[2/12] scratch setup"
  WALK_L3_SCRATCH="$WALK_SCRATCH/L3"
  export TMUX_TMPDIR="$WALK_L3_SCRATCH/tmux"
  mkdir -p "$TMUX_TMPDIR"
  unset GC_SESSION GC_BEADS GC_DOLT 2>/dev/null || true
  step_pass "scratch tree $WALK_L3_SCRATCH"

  echo
  echo "[3/12] copy my-factory templates"
  WALK_L3_FACTORY="$WALK_L3_SCRATCH/my-factory"
  mkdir -p "$WALK_L3_FACTORY"
  cp "$WALK_REPO_ROOT/my-factory/pack.toml.template" "$WALK_L3_FACTORY/pack.toml"
  cp "$WALK_REPO_ROOT/my-factory/city.toml.template" "$WALK_L3_FACTORY/city.toml"
  ln -s "$WALK_REPO_ROOT/packs" "$WALK_L3_SCRATCH/packs"
  step_pass "templates copied + packs symlinked"
  save_state WALK_L3_FACTORY

  echo
  echo "[4/12] gc register L3 factory"
  WALK_L3_CITY_NAME="sfi-walkthrough-L3-$run_id"
  local register_out
  register_out="$(cd "$WALK_L3_FACTORY" && gc register --name "$WALK_L3_CITY_NAME" . 2>&1)"
  if echo "$register_out" | grep -q "Registered city '$WALK_L3_CITY_NAME'"; then
    REGISTERED_CITY_PATHS+=("$WALK_L3_FACTORY")
    step_pass "registered $WALK_L3_CITY_NAME"
  else
    step_fail "gc register did not emit 'Registered city' marker"
    echo "$register_out" | head -10 | sed 's/^/    /' | tee -a "$WALK_LOG"
    fail "L3 factory register failed"
  fi
  save_state WALK_L3_CITY_NAME

  echo
  echo "[5/12] bundled rig + gc rig add"
  WALK_L3_RIG="$WALK_L3_SCRATCH/rig"
  cp -r "$WALK_REPO_ROOT/test-harness/tutorial-walkthrough-rig" "$WALK_L3_RIG"
  (cd "$WALK_L3_RIG" && git init -q && git add -A && git commit -qm "initial" >/dev/null 2>&1)
  # Capture the initial commit SHA so we can detect Builder commits later.
  local initial_sha
  initial_sha="$(cd "$WALK_L3_RIG" && git rev-parse HEAD)"
  step_pass "bundled rig at $WALK_L3_RIG (initial SHA $initial_sha)"

  if (cd "$WALK_L3_FACTORY" && gc rig add "$WALK_L3_RIG" >/dev/null 2>&1); then
    step_pass "gc rig add succeeded"
  else
    step_fail "gc rig add failed"
    fail "rig add failed"
  fi
  (cd "$WALK_L3_RIG" && bd config set types.custom "convoy") >/dev/null 2>&1 || true
  save_state WALK_L3_RIG

  echo
  echo "[6/12] factory up"
  (cd "$WALK_L3_FACTORY" && gc doctor --fix >/dev/null 2>&1) || true
  if ! wait_for "supervisor responsive" \
    "cd '$WALK_L3_FACTORY' && gc status >/dev/null 2>&1" 120 3; then
    fail "supervisor unresponsive"
  fi
  local agents_needed=(architect planner designer builder reviewer validator release-gate improver)
  local agent_pattern="${agents_needed[*]}"
  agent_pattern="${agent_pattern// /|}"
  if ! wait_for "all 8 agents visible in gc status" \
    "cd '$WALK_L3_FACTORY' && gc status 2>/dev/null | grep -cE '($agent_pattern)' | awk '{exit (\$1 >= 8 ? 0 : 1)}'" \
    120 4; then
    divergence "$WALK_LESSON_NAME" "fewer than 8 agents visible — proceeding"
  fi
  step_pass "factory up"
  start_event_stream "$WALK_L3_FACTORY"

  echo
  echo "[7/12] bd create (needs-plan)"
  if [ "$WALK_DRY_RUN" = "1" ]; then
    step_pass "dry run — skipping live-agent work"
    stop_event_stream
    return 0
  fi

  local bead_out
  bead_out="$(cd "$WALK_L3_RIG" && bd create \
    --title "Add a percent-of operation (percent(whole, fraction) returns whole*fraction/100) with proper rounding" \
    --label needs-plan 2>&1)"
  log "bd create output:"
  echo "$bead_out" | sed 's/^/    /' | tee -a "$WALK_LOG"

  WALK_L3_BEAD_ID="$(echo "$bead_out" | grep -oE '[a-z]+-[a-zA-Z0-9.]+' | head -1)"
  if [ -z "$WALK_L3_BEAD_ID" ]; then
    step_fail "could not extract bead id"
    stop_event_stream
    fail "bd create unparsable"
  fi
  step_pass "filed bead $WALK_L3_BEAD_ID"
  save_state WALK_L3_BEAD_ID

  # Expose generic aliases so shared helpers (run_stage, wait_for's
  # factory default) don't need per-lesson wiring.
  export WALK_FACTORY="$WALK_L3_FACTORY" WALK_RIG="$WALK_L3_RIG"

  echo
  echo "[8/12] Planner stage"
  # First-time sling on the root bead (already labeled needs-plan from [7]).
  if ! wait_for_agent_ready "$WALK_L3_FACTORY" rig/planner.planner 180 5; then
    step_fail "Planner session tmux never came live"
    stop_event_stream; fail "Planner session not ready"
  fi
  sling_and_nudge "$WALK_L3_FACTORY" rig/planner.planner "$WALK_L3_BEAD_ID"
  if [ "$SLING_RC" -ne 0 ]; then
    step_fail "sling to Planner produced no success marker"
    stop_event_stream; fail "Planner sling failed"
  fi
  local planner_check='
    count=$(find "'"$WALK_L3_RIG"'/work-packages" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " ")
    [ "$count" -ge 1 ]
  '
  local planner_rescue="rescue_dead_session '$WALK_RIG' '$WALK_L3_BEAD_ID' rig/planner.planner"
  if ! wait_for "Planner to write work-packages/*.md" "$planner_check" 600 15 "$planner_rescue" rig/planner.planner; then
    log "debugging — session list:"
    (cd "$WALK_L3_FACTORY" && gc session list 2>/dev/null | head -12 | sed 's/^/    /') | tee -a "$WALK_LOG"
    stop_event_stream; fail "Planner stage failed"
  fi
  WALK_L3_WORK_PACKAGE="$(find "$WALK_L3_RIG/work-packages" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Planner → $(basename "$WALK_L3_WORK_PACKAGE")"

  echo
  echo "[9/12] Architect stage"
  run_stage Architect needs-architecture rig/architect.architect docs/adr "$WALK_L3_BEAD_ID" 900 "percent-of operation" || {
    stop_event_stream; fail "Architect stage failed"
  }
  local arch_bead="$STAGE_BEAD"
  WALK_L3_ADR="$(find "$WALK_L3_RIG/docs/adr" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Architect → $(basename "$WALK_L3_ADR")"

  echo
  echo "[10/12] Designer stage"
  run_stage Designer needs-design rig/designer.designer docs/design "$arch_bead" 900 "percent-of operation" || {
    stop_event_stream; fail "Designer stage failed"
  }
  local design_bead="$STAGE_BEAD"
  WALK_L3_DESIGN_SPEC="$(find "$WALK_L3_RIG/docs/design" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Designer → $(basename "$WALK_L3_DESIGN_SPEC")"

  echo
  echo "[11/12] Builder stage — code + tests"
  # Builder writes code + commits on a feature branch, not an .md file,
  # so we can't use _stage — same bead-create-then-sling shape, but we
  # watch git log for the new commit instead of a file.
  log "[Builder] bd create --labels ready-to-build  (chains after $design_bead)"
  local build_bead
  build_bead="$(stage_bead_create "$WALK_L3_RIG" "Build: percent-of operation" ready-to-build "$design_bead")" || {
    step_fail "bd create failed for Builder"
    stop_event_stream; fail "Builder bead creation failed"
  }
  log "[Builder] → $build_bead"
  if ! wait_for_agent_ready "$WALK_L3_FACTORY" rig/builder.builder 180 5; then
    step_fail "Builder session tmux never came live"
    stop_event_stream; fail "Builder session not ready"
  fi
  sling_and_nudge "$WALK_L3_FACTORY" rig/builder.builder "$build_bead"
  if [ "$SLING_RC" -ne 0 ]; then
    step_fail "sling to Builder produced no success marker"
    stop_event_stream; fail "Builder sling failed"
  fi

  # Builder success = at least one new commit on a branch that isn't
  # the initial SHA. Check that we have a commit different from
  # initial_sha on ANY branch.
  local build_check='
    cd "'"$WALK_L3_RIG"'" && git log --all --oneline 2>/dev/null | grep -v "'"$(cd "$WALK_L3_RIG" && git log --oneline -1 "$initial_sha" 2>/dev/null | awk "{print \$1}")"'" | grep -q .
  '
  local builder_rescue="rescue_dead_session '$WALK_RIG' '$build_bead' rig/builder.builder"
  if ! wait_for "Builder to commit at least one new change" "$build_check" 900 20 "$builder_rescue" rig/builder.builder; then
    log "debugging — git log:"
    (cd "$WALK_L3_RIG" && git log --all --oneline 2>&1 | head -10 | sed 's/^/    /') | tee -a "$WALK_LOG"
    log "debugging — session list:"
    (cd "$WALK_L3_FACTORY" && gc session list 2>/dev/null | head -12 | sed 's/^/    /') | tee -a "$WALK_LOG"
    step_fail "Builder did not produce a new commit within 15min"
    stop_event_stream
    fail "Builder stage failed"
  fi
  WALK_L3_CODE_COMMITTED="$(cd "$WALK_L3_RIG" && git log --all --oneline | head -1)"
  step_pass "Builder committed: $WALK_L3_CODE_COMMITTED"

  echo
  echo "[12/12] verify tests pass on Builder's branch"
  # Find the branch with the newest commits. Checkout a detached HEAD
  # there so `node --test` runs against the Builder's work, not main.
  local builder_branch
  builder_branch="$(cd "$WALK_L3_RIG" && git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads/ | head -1)"
  log "newest branch: $builder_branch"
  (cd "$WALK_L3_RIG" && git checkout -q "$builder_branch" 2>&1) | sed 's/^/    /' | tee -a "$WALK_LOG" || true

  local test_out
  test_out="$(cd "$WALK_L3_RIG" && node --test 2>&1)"
  local test_rc=$?
  log "node --test output (last 20 lines):"
  echo "$test_out" | tail -20 | sed 's/^/    /' | tee -a "$WALK_LOG"
  if [ "$test_rc" -eq 0 ]; then
    step_pass "node --test passes on $builder_branch"
  else
    # Don't hard-fail — Builder may have left the branch in a partial
    # state. Record the divergence and continue so the user sees the
    # full picture.
    divergence "$WALK_LESSON_NAME" "Builder's tests failed on $builder_branch (exit $test_rc)"
    step_fail "tests failed on Builder's branch"
  fi

  # Structural content checks on the three markdown artifacts.
  if [ -n "$WALK_L3_WORK_PACKAGE" ]; then
    assert_artifact_has_sections "$WALK_L3_WORK_PACKAGE" \
      '^## (user story|acceptance criteria|overview|problem|goals?|scope)'
    assert_file_contains_at_least "$WALK_L3_WORK_PACKAGE" 1 \
      "work package: ≥1 user story ('As a ...')" '^[[:space:]]*([-*][[:space:]]+)?\*{0,2}As an? [a-zA-Z]'
    assert_file_contains_at_least "$WALK_L3_WORK_PACKAGE" 1 \
      "work package: ≥1 acceptance criterion" '^[[:space:]]*([-*][[:space:]]+(\[[ xX]\])?|[0-9]+\.)[[:space:]]'
  fi
  if [ -n "$WALK_L3_ADR" ]; then
    assert_artifact_has_sections "$WALK_L3_ADR" \
      '^## context' '^## (options|decision)'
    assert_file_contains_at_least "$WALK_L3_ADR" 2 \
      "ADR: ≥2 options considered" '\*\*[A-Z]\.[[:space:]]|^#{2,4}[[:space:]]+(Option|Alternative|Approach|Choice)[[:space:]]+[A-Z0-9]|^[-*][[:space:]]+\*{0,2}(Option|Alternative|Approach|Choice)[[:space:]]+[A-Z0-9]'
  fi
  if [ -n "$WALK_L3_DESIGN_SPEC" ]; then
    # README exit criterion: "Design spec written with Props / Interactions / Edge Cases / Test Plan sections"
    assert_artifact_has_sections "$WALK_L3_DESIGN_SPEC" \
      '^## (interface|props|inputs|api)' \
      '^## (interactions|behavior|flow)' \
      '^## (edge cases|error|states|failure)' \
      '^## (test plan|tests|testing|test cases)'
  fi

  log "what L3 produced (rig tree diff):"
  (cd "$WALK_L3_RIG" && git log --all --oneline --no-decorate | head -10 | sed 's/^/      /') | tee -a "$WALK_LOG"

  save_state WALK_L3_WORK_PACKAGE WALK_L3_ADR WALK_L3_DESIGN_SPEC WALK_L3_CODE_COMMITTED
  step_pass "L3: Planner → Architect → Designer → Builder chain complete"

  stop_event_stream
  return "$lesson_rc"
}

# --- main -------------------------------------------------------------

lesson_rc=0

lesson_prerequisites_check || exit 77
lesson_run
exit "$lesson_rc"
