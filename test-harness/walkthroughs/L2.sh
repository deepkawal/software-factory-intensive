#!/usr/bin/env bash
# L2.sh — Walkthrough for activities/labs/L2/README.md (Planner + Architect handoff).
#
# README mirrored:   activities/labs/L2/README.md
# Commands exercised: bd create --title ... --labels needs-plan,
#                     gc sling --nudge <rig>/planner.planner <bead>,
#                     fresh bd create with --labels needs-architecture,
#                     gc sling --nudge <rig>/architect.architect <new bead>.
#                     The command shapes match what the activity README
#                     tells students to type, with <rig> substituted to
#                     the harness's bundled rig name.
# Prerequisites:      none — lesson is self-contained
# Produces:           WALK_L2_FACTORY, WALK_L2_RIG, WALK_L2_CITY_NAME,
#                     WALK_L2_BEAD_ID, WALK_L2_WORK_PACKAGE, WALK_L2_ADR
# Expected runtime:   ~10-20 min live (factory bootstrap + two LLM stages)
# Live-agent stages:  Planner → work-package, Architect → ADR
#
# Each lesson spins up a fresh scratch factory instead of chaining off
# my-factory. This matches the real student flow (labs run days apart,
# always against a restarted factory) and keeps session state clean.

set -uo pipefail

source "$WALK_REPO_ROOT/test-harness/walkthroughs/_common.sh"

# --- prerequisites check ----------------------------------------------

lesson_prerequisites_check() {
  # No prerequisites — fresh factory per lesson.
  return 0
}

# --- body -------------------------------------------------------------

lesson_run() {
  local lesson_rc=0

  echo
  echo "[1/9] pre-flight"
  assert_walkthrough_preflight
  [ "$lesson_rc" -ne 0 ] && fail "pre-flight failed"
  purge_stranded_walkthrough_cities

  echo
  echo "[2/9] scratch setup"
  # L2 gets its own factory + rig under a per-lesson subdir so scratch
  # hygiene stays clean when lessons chain in time even if not in state.
  WALK_L2_SCRATCH="$WALK_SCRATCH/L2"
  # See my-factory.sh — do NOT set TMUX_TMPDIR under 1.0 launchd supervisor.
  unset GC_SESSION GC_BEADS GC_DOLT 2>/dev/null || true
  step_pass "scratch tree $WALK_L2_SCRATCH"

  echo
  echo "[3/9] copy my-factory templates"
  WALK_L2_FACTORY="$WALK_L2_SCRATCH/my-factory"
  mkdir -p "$WALK_L2_FACTORY"
  cp "$WALK_REPO_ROOT/my-factory/pack.toml.template" "$WALK_L2_FACTORY/pack.toml"
  cp "$WALK_REPO_ROOT/my-factory/city.toml.template" "$WALK_L2_FACTORY/city.toml"
  ln -s "$WALK_REPO_ROOT/packs" "$WALK_L2_SCRATCH/packs"
  WALK_L2_CITY_NAME="sfi-walkthrough-L2-$run_id"
  sed -i '' "s|^name = \"my-factory\"$|name = \"$WALK_L2_CITY_NAME\"|" "$WALK_L2_FACTORY/city.toml"
  step_pass "templates copied + packs symlinked at $WALK_L2_FACTORY"
  save_state WALK_L2_FACTORY

  echo
  echo "[4/9] gc register L2 factory"
  local register_out
  register_out="$(cd "$WALK_L2_FACTORY" && gc register --name "$WALK_L2_CITY_NAME" . 2>&1)"
  log "gc register output (first 10 lines):"
  echo "$register_out" | head -10 | sed 's/^/    /' | tee -a "$WALK_LOG"
  if echo "$register_out" | grep -q "Registered city '$WALK_L2_CITY_NAME'"; then
    REGISTERED_CITY_PATHS+=("$WALK_L2_FACTORY")
    step_pass "gc register --name $WALK_L2_CITY_NAME . registered city"
  else
    step_fail "gc register did not emit 'Registered city' marker"
    fail "L2 factory register failed"
  fi
  save_state WALK_L2_CITY_NAME

  echo
  echo "[5/9] hello-world rig + gc rig add"
  WALK_L2_RIG="$WALK_L2_SCRATCH/rig"
  cp -r "$WALK_REPO_ROOT/test-harness/tutorial-walkthrough-rig" "$WALK_L2_RIG"
  (cd "$WALK_L2_RIG" && git init -q && git add -A && git commit -qm "initial" >/dev/null 2>&1)
  step_pass "bundled rig copied + initial git commit"

  if (cd "$WALK_L2_FACTORY" && gc rig add "$WALK_L2_RIG" >/dev/null 2>&1); then
    step_pass "gc rig add succeeded"
  else
    step_fail "gc rig add failed"
    fail "rig add failed"
  fi
  (cd "$WALK_L2_RIG" && bd config set types.custom "convoy") >/dev/null 2>&1 || true
  save_state WALK_L2_RIG
  export WALK_FACTORY="$WALK_L2_FACTORY" WALK_RIG="$WALK_L2_RIG"

  echo
  echo "[6/9] factory up"
  (cd "$WALK_L2_FACTORY" && gc doctor --fix >/dev/null 2>&1) || true
  if ! wait_for "supervisor responsive" \
    "cd '$WALK_L2_FACTORY' && gc status >/dev/null 2>&1" 120 3; then
    fail "supervisor unresponsive"
  fi
  # Wait for all 8 agents to at least appear (they'll be stopped at first,
  # but presence is the bootstrap signal).
  local agents_needed=(architect planner designer builder reviewer validator release-gate improver)
  local agent_pattern="${agents_needed[*]}"
  agent_pattern="${agent_pattern// /|}"
  if ! wait_for "all 8 agents visible in gc status" \
    "cd '$WALK_L2_FACTORY' && gc status 2>/dev/null | grep -cE '($agent_pattern)' | awk '{exit (\$1 >= 8 ? 0 : 1)}'" \
    120 4; then
    divergence "$WALK_LESSON_NAME" "fewer than 8 agents visible — proceeding anyway"
  fi
  step_pass "factory up"
  start_event_stream "$WALK_L2_FACTORY"

  echo
  echo "[7/9] bd create (needs-plan)"
  if [ "$WALK_DRY_RUN" = "1" ]; then
    step_pass "dry run — skipping live-agent steps"
    stop_event_stream
    return 0
  fi
  local rig_tree_before
  rig_tree_before="$(cd "$WALK_L2_RIG" && find . -type f -not -path './.git/*' -not -path './.beads/*' | sort)"
  echo "$rig_tree_before" > "$WALK_L2_SCRATCH/rig-tree-before.txt"

  local bead_out
  bead_out="$(cd "$WALK_L2_RIG" && bd create \
    --title "Add memory feature: store, recall, and clear operations to the calculator" \
    --labels needs-plan 2>&1)"
  log "bd create output:"
  echo "$bead_out" | sed 's/^/    /' | tee -a "$WALK_LOG"

  WALK_L2_BEAD_ID="$(echo "$bead_out" | grep -oE 'rig-[a-zA-Z0-9.]+' | head -1)"
  if [ -z "$WALK_L2_BEAD_ID" ]; then
    step_fail "could not extract bead id"
    stop_event_stream
    fail "bd create output unparsable"
  fi
  step_pass "filed bead $WALK_L2_BEAD_ID with label needs-plan"
  save_state WALK_L2_BEAD_ID

  echo
  echo "[8/9] gc sling planner + wait for work-package"
  if ! wait_for_agent_ready "$WALK_L2_FACTORY" rig/planner.planner 180 5; then
    step_fail "Planner session tmux never came live"
    stop_event_stream; fail "Planner session not ready"
  fi
  sling_and_nudge "$WALK_L2_FACTORY" rig/planner.planner "$WALK_L2_BEAD_ID"
  if [ "$SLING_RC" -ne 0 ]; then
    step_fail "sling to Planner produced no success marker"
    stop_event_stream; fail "sling to planner failed — see $WALK_LOG"
  fi
  step_pass "Planner slung $WALK_L2_BEAD_ID"

  # Wait for Planner to produce a work-package file. Match any .md file
  # in work-packages/ (Planner may use any slug naming scheme).
  local wp_check='
    count=$(find "'"$WALK_L2_RIG"'/work-packages" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " ")
    [ "$count" -ge 1 ]
  '
  local planner_rescue="rescue_dead_session '$WALK_L2_RIG' '$WALK_L2_BEAD_ID' rig/planner.planner"
  if ! wait_for "Planner to write work-packages/*.md" "$wp_check" 600 15 "$planner_rescue" rig/planner.planner; then
    log "debugging — planner session state:"
    (cd "$WALK_L2_FACTORY" && gc session list 2>/dev/null | head -12 | sed 's/^/    /') | tee -a "$WALK_LOG"
    step_fail "Planner did not produce a work package within 10min"
    stop_event_stream
    fail "Planner failed to produce work-package"
  fi
  WALK_L2_WORK_PACKAGE="$(find "$WALK_L2_RIG/work-packages" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Planner produced work-package: $WALK_L2_WORK_PACKAGE"

  echo
  echo "[9/9] Architect stage — fresh bead chained to Planner"
  # Per-stage bead pattern (validated in L3): fresh bead with
  # `--deps blocks:<upstream>` then sling --nudge to the target.
  local arch_bead
  arch_bead="$(stage_bead_create "$WALK_L2_RIG" "Architecture: memory feature" needs-architecture "$WALK_L2_BEAD_ID")" || {
    step_fail "bd create for Architect failed"
    stop_event_stream; fail "Architect bead creation failed"
  }
  log "[Architect] → $arch_bead"
  if ! wait_for_agent_ready "$WALK_L2_FACTORY" rig/architect.architect 180 5; then
    step_fail "Architect session tmux never came live"
    stop_event_stream; fail "Architect session not ready"
  fi
  sling_and_nudge "$WALK_L2_FACTORY" rig/architect.architect "$arch_bead"
  if [ "$SLING_RC" -ne 0 ]; then
    step_fail "sling to Architect produced no success marker"
    stop_event_stream
    fail "sling to architect failed"
  fi
  step_pass "Architect slung $arch_bead"

  local adr_check='
    count=$(find "'"$WALK_L2_RIG"'/docs/adr" -maxdepth 1 -type f -name "*.md" 2>/dev/null | wc -l | tr -d " ")
    [ "$count" -ge 1 ]
  '
  local arch_rescue="rescue_dead_session '$WALK_L2_RIG' '$arch_bead' rig/architect.architect"
  if ! wait_for "Architect to write docs/adr/*.md" "$adr_check" 600 15 "$arch_rescue" rig/architect.architect; then
    log "debugging — architect session state:"
    (cd "$WALK_L2_FACTORY" && gc session list 2>/dev/null | head -12 | sed 's/^/    /') | tee -a "$WALK_LOG"
    step_fail "Architect did not produce an ADR within 10min"
    stop_event_stream
    fail "Architect failed to produce ADR"
  fi
  WALK_L2_ADR="$(find "$WALK_L2_RIG/docs/adr" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)"
  step_pass "Architect produced ADR: $WALK_L2_ADR"

  # Structural content checks against the reference-project artifact
  # shapes (Planner + Architect prompts target these sections).
  if [ -n "$WALK_L2_WORK_PACKAGE" ]; then
    assert_artifact_has_sections "$WALK_L2_WORK_PACKAGE" \
      '^## (User Story|Acceptance Criteria|Overview|Problem|Goals?)'
    # README exit criterion: "at least one user story and acceptance criteria"
    assert_file_contains_at_least "$WALK_L2_WORK_PACKAGE" 1 \
      "work package: ≥1 user story ('As a ...')" '^[[:space:]]*([-*][[:space:]]+)?\*{0,2}As an? [a-zA-Z]'
    assert_file_contains_at_least "$WALK_L2_WORK_PACKAGE" 1 \
      "work package: ≥1 acceptance criterion" '^[[:space:]]*([-*][[:space:]]+(\[[ xX]\])?|[0-9]+\.)[[:space:]]'
  fi
  if [ -n "$WALK_L2_ADR" ]; then
    assert_artifact_has_sections "$WALK_L2_ADR" \
      '^## Context' '^## (Options|Decision)'
    # README exit criterion: "ADR with at least two options considered"
    assert_file_contains_at_least "$WALK_L2_ADR" 2 \
      "ADR: ≥2 options considered" '\*\*[A-Z]\.[[:space:]]|^#{2,4}[[:space:]]+(Option|Alternative|Approach|Choice)[[:space:]]+[A-Z0-9]|^[-*][[:space:]]+\*{0,2}(Option|Alternative|Approach|Choice)[[:space:]]+[A-Z0-9]'
  fi

  log "what L2 produced (rig tree diff since lesson start):"
  (cd "$WALK_L2_RIG" && find . -type f -not -path './.git/*' -not -path './.beads/*' | sort \
    | diff "$WALK_L2_SCRATCH/rig-tree-before.txt" - | grep '^>' | sed 's/^> /      + /') | tee -a "$WALK_LOG"

  save_state WALK_L2_WORK_PACKAGE WALK_L2_ADR
  step_pass "L2 produced Planner work-package + Architect ADR"

  stop_event_stream
  return "$lesson_rc"
}

# --- main -------------------------------------------------------------

lesson_rc=0

lesson_prerequisites_check || exit 77
lesson_run
exit "$lesson_rc"
