#!/usr/bin/env bash
# tutorial-common.sh — Shared helpers for the SFI tutorial-check and
# tutorial-walkthrough harnesses. Source this after setting the two
# required variables below.
#
# Required from caller:
#   repo_root              — absolute path to the SFI repo root
#   TUTORIAL_SCRATCH_ROOT  — absolute path for this harness's scratch tree
#                            (e.g. /tmp/sfi-tutorial-check,
#                                  /tmp/sfi-tutorial-walkthrough)
#
# Provides:
#   run_id                       — unique suffix (seconds-$pid) for isolation
#   DIVERGENCES_LOG              — path under scratch root
#   FAILED_LESSONS[]             — bash array; lessons may append on failure
#   REGISTERED_CITY_PATHS[]      — bash array; cities to unregister in cleanup
#   cleanup()                    — trap handler (EXIT INT TERM)
#   divergence(), step_pass(), step_fail()
#   assert_gc_version_ge_015
#   assert_gc_doctor_healthy
#   assert_agent_doctor_checks_present
#
# The caller is responsible for:
#   - `set -uo pipefail` at top of its script
#   - `trap cleanup EXIT INT TERM` AFTER sourcing this file
#   - Running `rm -rf "$TUTORIAL_SCRATCH_ROOT" && mkdir -p "$TUTORIAL_SCRATCH_ROOT" && : > "$DIVERGENCES_LOG"`
#
# Not shared (intentionally per-harness):
#   - The scratch-root path itself (set by caller)
#   - The lesson functions (each harness has its own set)
#   - Any host-isolation / provider-shim logic — that belongs to the
#     walkthrough harness only, since tutorial-check explicitly does not
#     require auth.

if [ -z "${repo_root:-}" ]; then
  echo "tutorial-common.sh: caller must set \$repo_root before sourcing" >&2
  return 1 2>/dev/null || exit 1
fi
if [ -z "${TUTORIAL_SCRATCH_ROOT:-}" ]; then
  echo "tutorial-common.sh: caller must set \$TUTORIAL_SCRATCH_ROOT before sourcing" >&2
  return 1 2>/dev/null || exit 1
fi

DIVERGENCES_LOG="$TUTORIAL_SCRATCH_ROOT/divergences.log"
declare -a FAILED_LESSONS=()
declare -a REGISTERED_CITY_PATHS=()

# Unique suffix so parallel runs (and cohort users on the same machine)
# don't collide on registry names or scratch paths.
run_id="$(date +%s)-$$"

cleanup() {
  local rc=$?
  # Stop any still-running standalone controllers so unregister can tear
  # down state cleanly. Then unregister by absolute path (gc unregister
  # takes a path, not a --name — learned the hard way).
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

divergence() {
  local lesson="$1" detail="$2"
  echo "[$lesson] $detail" >> "$DIVERGENCES_LOG"
  echo "    ⚠ $detail"
}
step_pass() { echo "    ✓ $1"; }
# step_fail sets lesson_rc in the caller's scope (each lesson_* function
# declares `local lesson_rc=0` at its start).
step_fail() { echo "    ✗ $1" >&2; lesson_rc=1; }

assert_gc_version_ge_015() {
  local v
  v="$(gc version 2>&1 | tail -1 | tr -d ' \r\n')"
  case "$v" in
    0.1[5-9]*|0.[2-9]*|[1-9].*|[1-9][0-9]*.*) step_pass "gc version $v (≥ 0.15.0)" ;;
    *) step_fail "gc version $v — expected ≥ 0.15.0" ;;
  esac
}

# Prints doctor output to stdout (for further inspection by caller) and
# pass/fails on the two documented deprecation warnings.
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
