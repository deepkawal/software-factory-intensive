#!/usr/bin/env bash
# tutorial-walkthrough.sh — End-to-end workshop walkthrough dispatcher.
#
# Drives the Software Factory Intensive workshop through real live-LLM
# agent runs, one lesson at a time. Per-lesson bodies live under
# test-harness/walkthroughs/<lesson>.sh and are invoked here with a shared
# state.env so later lessons can chain off earlier ones (just like a
# real student's factory state accumulates across sessions).
#
# V1 scope: positional-arg dispatch only; no --lesson/--from/--list
# flags yet. Add those when we have >1 lesson to chain.
#
# Usage:
#   bash test-harness/tutorial-walkthrough.sh <lesson>        # run one lesson
#   bash test-harness/tutorial-walkthrough.sh                 # run all known lessons in order
#
# Environment:
#   TUTORIAL_WALKTHROUGH_DRY_RUN=1       — skip live-agent steps
#   TUTORIAL_WALKTHROUGH_KEEP_SCRATCH=1  — leave $WALK_SCRATCH for inspection
#
# Exit codes:
#   0  — all requested lessons passed
#   1  — one or more lessons failed
#   77 — lesson prerequisites not met (dispatcher aborts the chain)

set -uo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
WALK_REPO_ROOT="$repo_root"
# Canonical path (resolve /tmp → /private/tmp on macOS). gc rig add's
# server-reuse check compares process args as strings, so if gc register
# canonicalizes the cwd to /private/tmp/... and we then invoke gc rig add
# from /tmp/..., verify_our_server fails and rig-add tries to spawn a
# second dolt that collides on the start lock. Using the canonical path
# everywhere sidesteps that mismatch.
TUTORIAL_SCRATCH_ROOT="$(cd "$(mkdir -p /tmp/sfi-tutorial-walkthrough && echo /tmp/sfi-tutorial-walkthrough)" && pwd -P)"

# The library (run_id + cleanup + divergence/pass/fail + asserts). The
# library's cleanup handles unregister-by-path for everything in
# REGISTERED_CITY_PATHS; we wrap it below with walkthrough-specific
# pre-work (gc stop, tmux kill, scratch rm).
# shellcheck source=lib/tutorial-common.sh
source "$repo_root/test-harness/lib/tutorial-common.sh"

# Canonical lesson order. Add new lessons here as they land.
# Chaining order matches a real student's path through the curriculum:
# my-factory sets up the factory; each lab builds on the prior lab's
# state (work-package → ADR → design → code → review → release-gate).
ALL_LESSONS=(my-factory L2 L3 L4 C1)
# W1/L1/W2/W3/W4 intentionally skipped — see WORKSHOP_AUTHOR_NOTES.md
# §10 (L1) and §12 (workshops).

# --- state -------------------------------------------------------------

WALK_SCRATCH="$TUTORIAL_SCRATCH_ROOT/$run_id"
WALK_DIVERGENCES="$DIVERGENCES_LOG"
WALK_STATE_ENV="$WALK_SCRATCH/state.env"
WALK_DRY_RUN="${TUTORIAL_WALKTHROUGH_DRY_RUN:-0}"
export WALK_REPO_ROOT WALK_SCRATCH WALK_DIVERGENCES WALK_STATE_ENV WALK_DRY_RUN

# --- cleanup -----------------------------------------------------------

walkthrough_cleanup() {
  local rc=$?
  # Source state.env so we see WALK_FACTORY even if the lesson body
  # only exported it (and this cleanup runs after it exited).
  if [ -s "$WALK_STATE_ENV" ]; then
    set -a; source "$WALK_STATE_ENV"; set +a
  fi
  # Safety-net: kill any lesson-started event stream whose process
  # survived (lesson_run normally calls stop_event_stream, but if it
  # crashed or was interrupted the PID file may still be live).
  if [ -f "$WALK_SCRATCH/events.pid" ]; then
    local ev_pid
    ev_pid="$(cat "$WALK_SCRATCH/events.pid" 2>/dev/null)"
    if [ -n "$ev_pid" ] && kill -0 "$ev_pid" 2>/dev/null; then
      kill "$ev_pid" 2>/dev/null || true
    fi
    rm -f "$WALK_SCRATCH/events.pid"
  fi
  # Best-effort stop of any factory the lessons spun up.
  if [ -n "${WALK_FACTORY:-}" ] && [ -d "${WALK_FACTORY:-}" ]; then
    (cd "$WALK_FACTORY" 2>/dev/null && gc stop >/dev/null 2>&1) || true
  fi
  # Kill any tmux server rooted at our isolated TMUX_TMPDIR.
  if [ -n "${TMUX_TMPDIR:-}" ] && [ -d "${TMUX_TMPDIR:-}" ]; then
    tmux -S "$TMUX_TMPDIR/default" kill-server >/dev/null 2>&1 || true
  fi
  # Give the standalone controller's fds a beat to close before we
  # rm -rf (otherwise we get "Directory not empty" spam).
  sleep 2
  if [ "${TUTORIAL_WALKTHROUGH_KEEP_SCRATCH:-0}" = "1" ]; then
    echo
    echo "TUTORIAL_WALKTHROUGH_KEEP_SCRATCH=1 — scratch retained at: $WALK_SCRATCH"
  else
    rm -rf "$WALK_SCRATCH" 2>/dev/null || true
  fi
  # Library cleanup handles gc unregister per REGISTERED_CITY_PATHS and
  # prints the divergence summary, then exits with $rc.
  cleanup
}
trap walkthrough_cleanup EXIT INT TERM

rm -rf "$TUTORIAL_SCRATCH_ROOT"
mkdir -p "$WALK_SCRATCH"
: > "$DIVERGENCES_LOG"
: > "$WALK_STATE_ENV"

# --- args --------------------------------------------------------------

requested_lessons=( "$@" )
if [ "${#requested_lessons[@]}" -eq 0 ]; then
  requested_lessons=( "${ALL_LESSONS[@]}" )
fi

# Validate every requested lesson has a script.
for lesson in "${requested_lessons[@]}"; do
  if [ ! -f "$repo_root/test-harness/walkthroughs/$lesson.sh" ]; then
    echo "tutorial-walkthrough: no script at test-harness/walkthroughs/$lesson.sh" >&2
    exit 1
  fi
done

# --- dispatch ----------------------------------------------------------

echo "== tutorial-walkthrough =="
echo "repo: $repo_root"
echo "scratch: $WALK_SCRATCH"
echo "run_id: $run_id"
if [ "$WALK_DRY_RUN" = "1" ]; then
  echo "mode: DRY RUN"
fi
echo "lessons: ${requested_lessons[*]}"
echo

walkthrough_failed=0
for lesson in "${requested_lessons[@]}"; do
  echo
  echo "########################################################"
  echo "# LESSON: $lesson"
  echo "########################################################"

  # Re-source state.env so each lesson sees what prior lessons exported.
  # shellcheck disable=SC1090
  if [ -s "$WALK_STATE_ENV" ]; then
    set -a
    source "$WALK_STATE_ENV"
    set +a
  fi

  export WALK_LESSON_NAME="$lesson"
  lesson_script="$repo_root/test-harness/walkthroughs/$lesson.sh"

  bash "$lesson_script"
  lesson_rc=$?

  case "$lesson_rc" in
    0)
      echo "✓ $lesson passed"
      ;;
    77)
      echo "✗ $lesson: prerequisites not met — aborting chain" >&2
      walkthrough_failed=1
      break
      ;;
    *)
      echo "✗ $lesson: exit $lesson_rc" >&2
      walkthrough_failed=1
      # Continue running subsequent lessons? For v1: halt. If later we
      # want --continue-on-failure, flip this.
      break
      ;;
  esac
done

echo
if [ "$walkthrough_failed" -eq 0 ]; then
  if [ "$WALK_DRY_RUN" = "1" ]; then
    echo "✓ tutorial-walkthrough (dry run): ${#requested_lessons[@]} lesson(s) passed"
  else
    echo "✓ tutorial-walkthrough: ${#requested_lessons[@]} lesson(s) passed"
  fi
  exit 0
else
  echo "✗ tutorial-walkthrough: chain halted on failure"
  exit 1
fi
