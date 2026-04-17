#!/usr/bin/env bash
# tutorial-check.sh — Setup-phase harness for workshop READMEs.
#
# Walks through each lesson's setup steps in a scratch dir. Asserts
# documented commands exit 0 and that `gc doctor` emits the documented
# warning set with every agent pack's doctor check present.
#
# Records divergences (places where the harness substitutes
# non-interactive equivalents for interactive/auth steps, or rewrites
# paths so a scratch-dir run resolves imports) to
# /tmp/sfi-tutorial-check/divergences.log.
#
# Scope: setup/quickstart only. Does NOT spin up real agent sessions,
# does NOT require Claude auth. For end-to-end agent runs (gc start,
# bd create --label …, architect wakes and produces an ADR), see
# the separate tutorial-walkthrough harness (not yet built).
#
# Lessons covered:
#   1. my-factory/README.md            — main factory quickstart
#   2. activites/workshops/W2/README.md — W2 checkpoint factory
#   3. activites/labs/L2/README.md      — L2 checkpoint factory
#
# Exit codes:
#   0 — all lesson setups green
#   1 — one or more lessons failed

set -uo pipefail   # not -e; we handle errors per-lesson

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
scratch_root="/tmp/sfi-tutorial-check"
DIVERGENCES_LOG="$scratch_root/divergences.log"
declare -a FAILED_LESSONS=()
declare -a REGISTERED_CITY_PATHS=()

# Unique suffix so parallel runs (and cohort users) don't collide.
run_id="$(date +%s)-$$"

cleanup() {
  local rc=$?
  # Stop any still-running standalone controllers so unregister can tear down
  # state cleanly. Then unregister by absolute path (gc unregister takes a
  # path, not a --name — I learned this the hard way).
  for city_path in "${REGISTERED_CITY_PATHS[@]-}"; do
    [ -n "$city_path" ] || continue
    (cd "$city_path" 2>/dev/null && gc stop >/dev/null 2>&1) || true
    gc unregister "$city_path" >/dev/null 2>&1 || true
  done
  echo
  if [ -s "$DIVERGENCES_LOG" ]; then
    echo "Divergences logged ($(wc -l <"$DIVERGENCES_LOG" | tr -d ' ') entries): $DIVERGENCES_LOG"
  fi
  exit "$rc"
}
trap cleanup EXIT INT TERM

rm -rf "$scratch_root"
mkdir -p "$scratch_root"
: > "$DIVERGENCES_LOG"

divergence() {
  local lesson="$1" detail="$2"
  echo "[$lesson] $detail" >> "$DIVERGENCES_LOG"
  echo "    ⚠ $detail"
}
step_pass() { echo "    ✓ $1"; }
step_fail() { echo "    ✗ $1" >&2; lesson_rc=1; }

# --- Shared assertion helpers -------------------------------------------

assert_gc_version_ge_015() {
  local v
  v="$(gc version 2>&1 | tail -1 | tr -d ' \r\n')"
  case "$v" in
    0.1[5-9]*|0.[2-9]*|[1-9].*|[1-9][0-9]*.*) step_pass "gc version $v (≥ 0.15.0)" ;;
    *) step_fail "gc version $v — expected ≥ 0.15.0" ;;
  esac
}

assert_gc_doctor_healthy() {
  local city_dir="$1" doctor_out
  doctor_out="$(cd "$city_dir" && gc doctor 2>&1)"
  # Expected documented warnings (workshop:#781, #600).
  if echo "$doctor_out" | grep -q 'v2-default-rig-import-format'; then
    step_pass "gc doctor emits documented v2-default-rig-import-format warning"
  else
    step_fail "gc doctor missing documented v2-default-rig-import-format warning"
  fi
  if echo "$doctor_out" | grep -q 'v2-workspace-name'; then
    step_pass "gc doctor emits documented v2-workspace-name warning"
  else
    step_fail "gc doctor missing documented v2-workspace-name warning"
  fi
  echo "$doctor_out"
}

assert_agent_doctor_checks_present() {
  local doctor_out="$1"
  shift
  local agent
  for agent in "$@"; do
    if echo "$doctor_out" | grep -q ":check-${agent}"; then
      step_pass "$agent doctor check present"
    else
      step_fail "$agent doctor check missing from gc doctor output"
    fi
  done
}

# --- Lesson 1: my-factory/README.md main quickstart ---------------------

lesson_my_factory() {
  local lesson="my-factory"
  local lesson_rc=0
  echo "== $lesson (main quickstart) =="

  local scratch="$scratch_root/$lesson"
  rm -rf "$scratch"
  mkdir -p "$scratch"

  # Fabricate a scratch workspace that mirrors the cloned-repo layout: the
  # factory lives at $scratch/my-factory/ and `../packs/` must resolve to
  # the real packs tree. We symlink instead of copying — faster and keeps
  # a single source of truth for pack content.
  ln -s "$repo_root/packs" "$scratch/packs"
  mkdir -p "$scratch/my-factory"
  cp "$repo_root/my-factory/pack.toml.template" "$scratch/my-factory/"
  cp "$repo_root/my-factory/city.toml.template" "$scratch/my-factory/"
  divergence "$lesson" "Scratch workspace uses a symlink to the repo's packs/ rather than a fresh clone — testing content parity, not clone mechanics"

  # Step 1: gc version >= 0.15.0 (README step 1).
  assert_gc_version_ge_015

  # Step 2: copy templates → runtime files (README step 2).
  (cd "$scratch/my-factory" && cp pack.toml.template pack.toml && cp city.toml.template city.toml)
  if [ -f "$scratch/my-factory/pack.toml" ] && [ -f "$scratch/my-factory/city.toml" ]; then
    step_pass "template → runtime copy produced pack.toml and city.toml"
  else
    step_fail "template copy did not produce runtime files"
    return 1
  fi

  # Step 3: gc register (README step 3).
  # Use --name with a unique suffix so parallel runs (and the user's real
  # my-factory) don't collide on the supervisor registry.
  local city_name="my-factory-tc-$run_id"
  divergence "$lesson" "README 'gc register .' → harness 'gc register --name $city_name .' for registry isolation"
  local register_out
  register_out="$(cd "$scratch/my-factory" && gc register --name "$city_name" . 2>&1)"
  if gc cities 2>/dev/null | grep -q "^${city_name}\s"; then
    REGISTERED_CITY_PATHS+=("$(cd "$scratch/my-factory" && pwd)")
    step_pass "gc register --name $city_name . registered city"
    if echo "$register_out" | grep -q 'reconcile did not finish'; then
      divergence "$lesson" "gc register reported 'reconcile did not finish before timeout' on fresh supervisor — city IS registered, supervisor will retry reconcile"
    fi
  else
    step_fail "gc register --name $city_name . did not register the city"
    echo "$register_out" | tail -5 >&2
    return 1
  fi

  # Step 4: gc rig add (README step 4).
  local rig_dir="$scratch/your-project"
  mkdir -p "$rig_dir"
  (cd "$rig_dir" && git init -q && touch README.md && git add -A && git commit -qm "init" >/dev/null 2>&1)
  divergence "$lesson" "README 'gc rig add ~/Projects/your-project' → harness 'gc rig add $rig_dir' (scratch project dir)"
  if (cd "$scratch/my-factory" && gc rig add "$rig_dir" >/dev/null 2>&1); then
    step_pass "gc rig add succeeded"
  else
    step_fail "gc rig add failed"
    return 1
  fi

  # Step 5: bd convoy config (README step 5). Tolerate failures — bd may
  # or may not be wired up in every test env.
  if bd config set types.custom "convoy" >/dev/null 2>&1; then
    step_pass "bd config set types.custom convoy (factory side)"
  else
    divergence "$lesson" "bd config set types.custom convoy skipped — bd config command unavailable or no default store"
  fi

  # Skipped per scope: gc restart, gc status agent-session view, gc dashboard,
  # and bd create --label needs-architecture. All require live agent sessions
  # and/or real Claude auth. The walkthrough harness covers these.
  divergence "$lesson" "README steps 6-7 (gc restart, gc status, gc dashboard serve, bd create --label …) skipped — require live agent sessions; out of scope for tutorial-check"

  # Step 6 (harness-scoped): gc doctor assertions.
  local doctor_out
  doctor_out="$(assert_gc_doctor_healthy "$scratch/my-factory")"
  assert_agent_doctor_checks_present "$doctor_out" \
    architect builder designer improver planner reviewer release-gate validator

  echo
  return "$lesson_rc"
}

# --- Lesson 2: activites/workshops/W2/README.md checkpoint --------------

lesson_w2_checkpoint() {
  local lesson="w2-checkpoint"
  local lesson_rc=0
  echo "== $lesson (W2 checkpoint factory) =="

  local checkpoint_src="$repo_root/activites/workshops/W2/gascity/step_0/packs"
  local scratch="$scratch_root/$lesson"
  rm -rf "$scratch"
  mkdir -p "$(dirname "$scratch")"
  cp -r "$checkpoint_src" "$scratch"
  divergence "$lesson" "Scratch workspace copied from checkpoint source; runtime copies are gitignored so no collision with committed templates"

  assert_gc_version_ge_015

  (cd "$scratch" && cp pack.toml.template pack.toml && cp city.toml.template city.toml)
  if [ -f "$scratch/pack.toml" ] && [ -f "$scratch/city.toml" ]; then
    step_pass "template → runtime copy produced pack.toml and city.toml"
  else
    step_fail "template copy did not produce runtime files"
    return 1
  fi

  local city_name="w2-step-0-tc-$run_id"
  divergence "$lesson" "README 'gc register --name w2-step-0 .' → harness 'gc register --name $city_name .' for registry isolation"
  # gc register may exit non-zero with "reconcile did not finish before
  # timeout" on fresh-supervisor runs while still successfully registering
  # the city. Verify registration via `gc cities` rather than relying on
  # exit code.
  local register_out
  register_out="$(cd "$scratch" && gc register --name "$city_name" . 2>&1)"
  if gc cities 2>/dev/null | grep -q "^${city_name}\s"; then
    REGISTERED_CITY_PATHS+=("$(cd "$scratch" && pwd)")
    step_pass "gc register --name $city_name . registered city"
    if echo "$register_out" | grep -q 'reconcile did not finish'; then
      divergence "$lesson" "gc register reported 'reconcile did not finish before timeout' on fresh supervisor — city IS registered, supervisor will retry reconcile"
    fi
  else
    step_fail "gc register --name $city_name . did not register the city"
    echo "$register_out" | tail -5 >&2
    return 1
  fi

  local rig_dir="$scratch/w2-project"
  mkdir -p "$rig_dir"
  (cd "$rig_dir" && git init -q && touch README.md && git add -A && git commit -qm "init" >/dev/null 2>&1)
  divergence "$lesson" "README 'gc rig add ~/Projects/factory/workshop_w2/w2-project' → harness 'gc rig add $rig_dir'"
  if (cd "$scratch" && gc rig add "$rig_dir" >/dev/null 2>&1); then
    step_pass "gc rig add succeeded"
  else
    step_fail "gc rig add failed"
    return 1
  fi

  divergence "$lesson" "README steps 5-6 (gc restart, gc dashboard, bd create --label …) skipped — require live agent sessions"

  local doctor_out
  doctor_out="$(assert_gc_doctor_healthy "$scratch")"
  # W2 has 9 agents: 8 canonical minus release-gate (renamed to deployer in W2) + deployer itself.
  # deployer pack has no doctor/ dir by design — assert only agents that DO have doctor checks.
  assert_agent_doctor_checks_present "$doctor_out" \
    architect builder designer improver planner reviewer validator
  # Verify deployer is discovered as an agent via `gc config show` — the
  # supervisor-independent resolved-config dump. Deployer has no doctor
  # check and no commands, so neither gc doctor nor gc --help surface it,
  # and gc status is supervisor-reconcile-gated (can take 30-60s on fresh
  # supervisor). gc config show runs in ~100ms and reflects the city's
  # materialized agent list directly.
  if (cd "$scratch" && gc config show 2>&1 | grep -q 'name = "deployer"'); then
    step_pass "deployer agent present in gc config show"
  else
    step_fail "deployer agent not found in gc config show"
  fi

  echo
  return "$lesson_rc"
}

# --- Lesson 3: activites/labs/L2/README.md checkpoint -------------------

lesson_l2_checkpoint() {
  local lesson="l2-checkpoint"
  local lesson_rc=0
  echo "== $lesson (L2 checkpoint factory) =="

  local checkpoint_src="$repo_root/activites/labs/L2/gascity/step_0/packs"
  local scratch="$scratch_root/$lesson"
  rm -rf "$scratch"
  mkdir -p "$(dirname "$scratch")"
  cp -r "$checkpoint_src" "$scratch"
  divergence "$lesson" "Scratch workspace copied from checkpoint source"

  assert_gc_version_ge_015

  (cd "$scratch" && cp pack.toml.template pack.toml && cp city.toml.template city.toml)
  if [ -f "$scratch/pack.toml" ] && [ -f "$scratch/city.toml" ]; then
    step_pass "template → runtime copy produced pack.toml and city.toml"
  else
    step_fail "template copy did not produce runtime files"
    return 1
  fi

  local city_name="l2-step-0-tc-$run_id"
  divergence "$lesson" "README 'gc register --name l2-step-0 .' → harness 'gc register --name $city_name .' for registry isolation"
  # gc register may exit non-zero with "reconcile did not finish before
  # timeout" on fresh-supervisor runs while still successfully registering
  # the city. Verify registration via `gc cities` rather than relying on
  # exit code.
  local register_out
  register_out="$(cd "$scratch" && gc register --name "$city_name" . 2>&1)"
  if gc cities 2>/dev/null | grep -q "^${city_name}\s"; then
    REGISTERED_CITY_PATHS+=("$(cd "$scratch" && pwd)")
    step_pass "gc register --name $city_name . registered city"
    if echo "$register_out" | grep -q 'reconcile did not finish'; then
      divergence "$lesson" "gc register reported 'reconcile did not finish before timeout' on fresh supervisor — city IS registered, supervisor will retry reconcile"
    fi
  else
    step_fail "gc register --name $city_name . did not register the city"
    echo "$register_out" | tail -5 >&2
    return 1
  fi

  local rig_dir="$scratch/l2-project"
  mkdir -p "$rig_dir"
  (cd "$rig_dir" && git init -q && touch README.md && git add -A && git commit -qm "init" >/dev/null 2>&1)
  divergence "$lesson" "README 'gc rig add ~/Projects/factory/lab_l2/l2-project' → harness 'gc rig add $rig_dir'"
  if (cd "$scratch" && gc rig add "$rig_dir" >/dev/null 2>&1); then
    step_pass "gc rig add succeeded"
  else
    step_fail "gc rig add failed"
    return 1
  fi

  divergence "$lesson" "README steps 5-6 (gc restart, gc dashboard, bd create --label …) skipped — require live agent sessions"

  local doctor_out
  doctor_out="$(assert_gc_doctor_healthy "$scratch")"
  # L2 has only architect + planner.
  assert_agent_doctor_checks_present "$doctor_out" architect planner

  echo
  return "$lesson_rc"
}

# --- Main ---------------------------------------------------------------

echo "== tutorial-check =="
echo "repo: $repo_root"
echo "scratch: $scratch_root"
echo "run_id: $run_id"
echo

lesson_my_factory    || FAILED_LESSONS+=("my-factory")
lesson_w2_checkpoint || FAILED_LESSONS+=("w2-checkpoint")
lesson_l2_checkpoint || FAILED_LESSONS+=("l2-checkpoint")

echo
if [ "${#FAILED_LESSONS[@]}" -eq 0 ]; then
  echo "✓ tutorial-check passes (3 lessons green)"
  exit 0
else
  echo "✗ tutorial-check: ${#FAILED_LESSONS[@]} lesson(s) failed: ${FAILED_LESSONS[*]}" >&2
  exit 1
fi
