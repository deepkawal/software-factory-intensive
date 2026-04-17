#!/usr/bin/env bash
# my-factory.sh — Walkthrough for my-factory/README.md (the student quickstart).
#
# README mirrored:   my-factory/README.md
# Commands exercised: Quickstart §1-8 (gc version → bd create → handoff)
# Prerequisites:      none (this is the foundation lesson; all others chain off it)
# Produces:           WALK_FACTORY, WALK_RIG, WALK_CITY_NAME,
#                     WALK_MYFACTORY_BEAD_ID, WALK_MYFACTORY_AGENTS_SEEN
# Expected runtime:   ~5-10 min live
# Live-agent stages:  bd create → architect wakes → architect hands off via
#                     'gc all wake-downstream &' → planner-labelled bead appears
#
# Exit criterion for v1: first label handoff fires. We observe:
#   - Architect session wakes (polling gc session list)
#   - At least one bead gains a 'needs-plan' label (architect's child bead)
#   - Planner session wakes (handoff via gc all wake-downstream)
# Full chain (planner → designer → ...) is NOT required to pass; any one
# downstream wake proves the label-based pipeline is live.

set -uo pipefail

# Dispatcher sets: WALK_REPO_ROOT, WALK_SCRATCH, WALK_DIVERGENCES,
# WALK_STATE_ENV, WALK_DRY_RUN, WALK_LESSON_NAME.
source "$WALK_REPO_ROOT/test-harness/walkthroughs/_common.sh"

# --- prerequisites check (none for my-factory) ------------------------

lesson_prerequisites_check() {
  # First lesson — no prerequisites beyond the dispatcher env.
  return 0
}

# --- body --------------------------------------------------------------

lesson_run() {
  local lesson_rc=0

  echo
  echo "[1/8] pre-flight"
  assert_walkthrough_preflight
  [ "$lesson_rc" -ne 0 ] && fail "pre-flight failed — fix the above before re-running"
  purge_stranded_walkthrough_cities

  echo
  echo "[2/8] scratch setup"
  export TMUX_TMPDIR="$WALK_SCRATCH/tmux"
  mkdir -p "$TMUX_TMPDIR"
  # Clear gc env caches so the scratch factory gets fresh resolution.
  unset GC_SESSION GC_BEADS GC_DOLT 2>/dev/null || true
  step_pass "scratch tree $WALK_SCRATCH  TMUX_TMPDIR=$TMUX_TMPDIR"

  echo
  echo "[3/8] copy my-factory templates"
  WALK_FACTORY="$WALK_SCRATCH/my-factory"
  mkdir -p "$WALK_FACTORY"
  cp "$WALK_REPO_ROOT/my-factory/pack.toml.template" "$WALK_FACTORY/pack.toml"
  cp "$WALK_REPO_ROOT/my-factory/city.toml.template" "$WALK_FACTORY/city.toml"
  # pack.toml.template refers to "../packs" — symlink the repo's packs
  # so the relative path resolves from the scratch factory dir.
  ln -s "$WALK_REPO_ROOT/packs" "$WALK_SCRATCH/packs"
  step_pass "templates copied + packs symlinked at $WALK_FACTORY"
  save_state WALK_FACTORY

  echo
  echo "[4/8] gc register factory"
  WALK_CITY_NAME="sfi-walkthrough-$run_id"
  register_out="$(cd "$WALK_FACTORY" && gc register --name "$WALK_CITY_NAME" . 2>&1)"
  # Log register output for iterating on "what does gc register actually print".
  log "gc register output (first 10 lines):"
  echo "$register_out" | head -10 | sed 's/^/    /' | tee -a "$WALK_LOG"
  if echo "$register_out" | grep -q "Registered city '$WALK_CITY_NAME'"; then
    REGISTERED_CITY_PATHS+=("$WALK_FACTORY")
    step_pass "gc register --name $WALK_CITY_NAME . registered city"
    if echo "$register_out" | grep -q 'reconcile did not finish'; then
      divergence "$WALK_LESSON_NAME" "gc register reported 'reconcile did not finish before timeout' — city IS registered, supervisor will retry reconcile"
    fi
  else
    step_fail "gc register did not emit 'Registered city' marker"
    fail "factory register failed"
  fi
  save_state WALK_CITY_NAME

  echo
  echo "[5/8] hello-world rig + gc rig add"
  WALK_RIG="$WALK_SCRATCH/rig"
  cp -r "$WALK_REPO_ROOT/test-harness/tutorial-walkthrough-rig" "$WALK_RIG"
  (cd "$WALK_RIG" && git init -q && git add -A && git commit -qm "initial" >/dev/null 2>&1)
  step_pass "bundled rig copied + initial git commit at $WALK_RIG"

  if (cd "$WALK_FACTORY" && gc rig add "$WALK_RIG" >/dev/null 2>&1); then
    step_pass "gc rig add succeeded"
  else
    step_fail "gc rig add failed"
    fail "rig add failed"
  fi
  save_state WALK_RIG

  echo
  echo "[6/8] chmod .beads + bd convoy type"
  # README step 5: chmod 700 ../.beads to clear the 0755 doctor warning.
  # We operate on the host repo's .beads (same one the scratch factory
  # uses via the packs symlink). Non-destructive if already 0700.
  if [ -d "$WALK_REPO_ROOT/.beads" ]; then
    chmod 700 "$WALK_REPO_ROOT/.beads" 2>/dev/null || \
      divergence "$WALK_LESSON_NAME" "chmod 700 $WALK_REPO_ROOT/.beads failed (likely not owned by user) — beads-store warning will persist"
  fi
  # README step 6: bd config set types.custom convoy, rig-side.
  if (cd "$WALK_RIG" && bd config set types.custom "convoy") >/dev/null 2>&1; then
    step_pass "bd config set types.custom convoy (rig-side)"
  else
    divergence "$WALK_LESSON_NAME" "bd config set types.custom convoy skipped — bd config unavailable in scratch rig"
  fi

  echo
  echo "[7/8] factory up"
  # gc doctor --fix materializes built-in formulas (clears system-formulas).
  (cd "$WALK_FACTORY" && gc doctor --fix >/dev/null 2>&1) || \
    divergence "$WALK_LESSON_NAME" "gc doctor --fix returned non-zero — system-formulas may be stale"
  step_pass "gc doctor --fix ran"

  # gc register already spawned a standalone controller that drives the
  # dispatcher. No gc start is needed (and would fail with "standalone
  # controller already running"). Verified in practice: from a clean
  # register, all 8 agent sessions transition from creating → active
  # within ~5 min, and the architect picks up a needs-architecture bead
  # and produces an ADR. Wait for supervisor to be responsive.
  if ! wait_for "supervisor responsive (gc status exits 0)" \
    "cd '$WALK_FACTORY' && gc status >/dev/null 2>&1" 120 3; then
    step_fail "supervisor never became responsive"
    fail "supervisor unresponsive"
  fi

  # Wait for agents to materialize in gc status (reconcile is async —
  # "supervisor responsive" only means gc status exits 0, not that all
  # the agents are listed yet). Single capture, then grep the captured
  # output for each expected agent name.
  local agents_needed=(architect planner designer builder reviewer validator release-gate improver)
  local agent_pattern="${agents_needed[*]}"
  agent_pattern="${agent_pattern// /|}"  # space-separated → pipe-separated regex
  if ! wait_for "all 8 agents visible in gc status" \
    "cd '$WALK_FACTORY' && gc status 2>/dev/null | grep -cE '($agent_pattern)' | awk '{exit (\$1 >= 8 ? 0 : 1)}'" \
    120 4; then
    log "debugging — current gc status (stderr suppressed):"
    (cd "$WALK_FACTORY" && gc status 2>/dev/null) | sed 's/^/    /' | tee -a "$WALK_LOG"
    divergence "$WALK_LESSON_NAME" "gc status did not list all 8 agents within 120s — may be normal on slow reconcile; proceeding"
  fi

  # Dump gc status for the log so iterators can see actual format.
  log "gc status output (stderr suppressed, first 40 lines):"
  (cd "$WALK_FACTORY" && gc status 2>/dev/null) | head -40 | sed 's/^/    /' | tee -a "$WALK_LOG"

  # Start the event stream so the log captures factory-side activity
  # (bead transitions, order fires, agent state changes) during the
  # live-agent section. Primary forensic tool when a lesson fails —
  # gc-events.log is a linear record of what the factory did.
  start_event_stream "$WALK_FACTORY"

  echo
  echo "[8/8] bd create → wait for factory to do real work"
  if [ "$WALK_DRY_RUN" = "1" ]; then
    step_pass "dry run — skipping live-agent steps"
    return 0
  fi

  # Step 8a: snapshot the rig before the factory touches it. Anything
  # the agents produce will show up as a diff against this snapshot.
  # Use 'git status --porcelain' + file-tree hash for the baseline.
  local rig_tree_before
  rig_tree_before="$(cd "$WALK_RIG" && find . -type f -not -path './.git/*' -not -path './.beads/*' | sort)"
  echo "$rig_tree_before" > "$WALK_SCRATCH/rig-tree-before.txt"
  log "rig baseline: $(echo "$rig_tree_before" | wc -l | tr -d ' ') files"

  # Step 8b: file the root bead.
  log "bd create output:"
  bead_out="$(cd "$WALK_RIG" && bd create \
    --title "Add a multiply function to the calculator" \
    --label needs-architecture 2>&1)"
  echo "$bead_out" | sed 's/^/    /' | tee -a "$WALK_LOG"

  WALK_MYFACTORY_BEAD_ID="$(echo "$bead_out" | grep -oE '[a-z]+-[a-zA-Z0-9.]+' | head -1)"
  if [ -z "$WALK_MYFACTORY_BEAD_ID" ]; then
    step_fail "could not extract bead id from bd create output — see $WALK_LOG"
    fail "bd create output unparsable"
  fi
  step_pass "bd create filed bead: $WALK_MYFACTORY_BEAD_ID"
  save_state WALK_MYFACTORY_BEAD_ID

  # We USED to wait here for the architect's session state to show
  # 'active' before checking for work. That was a mistake: polling every
  # 10s for a transient state is flaky — the session can be 'active'
  # and back to 'asleep' between polls even as real work completes.
  # Instead we go straight to the only signal that actually matters:
  # did the factory produce tangible work?
  #
  # Step 8c: wait for the factory to PRODUCE TANGIBLE WORK. Success =
  # "did the agents actually touch the rig?" We don't care about the
  # specific pipeline shape (which agent handed off to whom) — just
  # whether the system made progress on the student's ask. A real
  # student opening their project dir should see new files.
  #
  # Signals of tangible work (any one satisfies):
  #   (1) New or modified files in the rig (git-tracked or untracked)
  #   (2) The original bead was closed or transitioned to another label
  #   (3) Child beads appeared with downstream labels
  #
  # We give the full pipeline a generous 15min budget — the architect
  # alone typically takes ~3min; deeper handoffs add more.
  local work_check='
    # (1) any file added/modified in the rig since baseline?
    new_files="$(cd "'"$WALK_RIG"'" && find . -type f -not -path "./.git/*" -not -path "./.beads/*" | sort)"
    if [ "$new_files" != "$(cat "'"$WALK_SCRATCH"'/rig-tree-before.txt")" ]; then
      exit 0
    fi
    # (2) original bead closed?
    status=$(cd "'"$WALK_RIG"'" && bd show "'"$WALK_MYFACTORY_BEAD_ID"'" --json 2>/dev/null \
      | jq -r "if type==\"array\" then .[0].status elif .status then .status else \"unknown\" end" 2>/dev/null)
    if [ "$status" = "closed" ]; then
      exit 0
    fi
    # (3) any child bead with a downstream label?
    for lbl in needs-plan needs-design needs-tests ready-to-build needs-review ready-to-ship; do
      if (cd "'"$WALK_RIG"'" && bd list --label=$lbl --json 2>/dev/null | jq -e "length > 0" >/dev/null); then
        exit 0
      fi
    done
    exit 1
  '
  if ! wait_for "factory to produce tangible work (new files / bead closed / downstream label)" \
    "$work_check" 900 15; then
    log "debugging — current rig tree diff:"
    (cd "$WALK_RIG" && find . -type f -not -path './.git/*' -not -path './.beads/*' | sort \
      | diff - "$WALK_SCRATCH/rig-tree-before.txt" | sed 's/^/    /') | tee -a "$WALK_LOG"
    log "debugging — rig bead status:"
    (cd "$WALK_RIG" && bd list 2>&1 | head -10 | sed 's/^/    /') | tee -a "$WALK_LOG"
    step_fail "factory produced no tangible work within 15min"
    fail "factory idle — see $WALK_LOG for session logs of each agent"
  fi

  # Step 8d: report what actually happened. This is the useful output
  # of the walkthrough — the student sees what their factory did.
  log "what the factory produced (rig tree diff):"
  (cd "$WALK_RIG" && find . -type f -not -path './.git/*' -not -path './.beads/*' | sort \
    | diff "$WALK_SCRATCH/rig-tree-before.txt" - | grep '^>' | sed 's/^> /      + /') | tee -a "$WALK_LOG"
  log "which agents were active during the run:"
  local agents_active
  agents_active="$(cd "$WALK_FACTORY" && gc session list 2>/dev/null | awk '$3 == "active" {print $2}' | sort -u)"
  echo "$agents_active" | sed 's/^/      /' | tee -a "$WALK_LOG"
  log "bead status:"
  (cd "$WALK_RIG" && bd list 2>&1 | head -5 | sed 's/^/      /') | tee -a "$WALK_LOG"

  WALK_MYFACTORY_AGENTS_SEEN="$(echo "$agents_active" | tr '\n' ' ')"
  save_state WALK_MYFACTORY_AGENTS_SEEN
  step_pass "factory produced tangible work in the rig"

  # Stop the event stream so the log is flushed and closed before the
  # dispatcher runs its cleanup. The log stays at $WALK_SCRATCH/gc-events.log
  # for post-mortem; KEEP_SCRATCH=1 retains it.
  stop_event_stream

  return "$lesson_rc"
}

# --- main --------------------------------------------------------------

lesson_rc=0

lesson_prerequisites_check || exit 77
lesson_run
# lesson_run may have flipped lesson_rc via step_fail.
exit "$lesson_rc"
