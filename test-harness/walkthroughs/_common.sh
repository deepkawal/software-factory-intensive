#!/usr/bin/env bash
# test-harness/walkthroughs/_common.sh — shared helpers for per-lesson walkthrough scripts.
#
# Sourced by each test-harness/walkthroughs/<lesson>.sh. Assumes the
# dispatcher has set WALK_REPO_ROOT, WALK_SCRATCH, WALK_DIVERGENCES,
# WALK_STATE_ENV, WALK_DRY_RUN, WALK_LESSON_NAME before invoking.
#
# Also sources the setup-phase library for step_pass/step_fail/
# divergence/assert_gc_* — so lesson scripts have both sets of helpers.

if [ -z "${WALK_REPO_ROOT:-}" ]; then
  echo "_common.sh: WALK_REPO_ROOT not set — this file is sourced by test-harness/walkthroughs/<lesson>.sh, which is invoked by test-harness/tutorial-walkthrough.sh" >&2
  return 1 2>/dev/null || exit 1
fi

# Setup-phase helpers. The library expects repo_root + TUTORIAL_SCRATCH_ROOT.
repo_root="$WALK_REPO_ROOT"
TUTORIAL_SCRATCH_ROOT="$(dirname "$WALK_SCRATCH")"
# shellcheck source=../lib/tutorial-common.sh
source "$WALK_REPO_ROOT/test-harness/lib/tutorial-common.sh"

# --- Per-lesson log ----------------------------------------------------

WALK_LOG="$WALK_SCRATCH/$WALK_LESSON_NAME.log"
: > "$WALK_LOG"

log() {
  # Append to per-lesson log and stdout. Timestamps help when iterating
  # on a run that hangs.
  local line
  line="$(date +%H:%M:%S) $*"
  echo "$line" | tee -a "$WALK_LOG"
}
fail() {
  echo "✗ $*" >&2
  echo "$(date +%H:%M:%S) FAIL: $*" >> "$WALK_LOG"
  exit 1
}

# --- State.env plumbing ------------------------------------------------

# Call once after setting shell vars you want to export to later lessons:
#   save_state WALK_FACTORY WALK_RIG WALK_CITY_NAME
save_state() {
  local var
  for var in "$@"; do
    # Only export if the var has a value.
    if [ -n "${!var:-}" ]; then
      # Strip any prior line for this var, then append fresh.
      if [ -f "$WALK_STATE_ENV" ]; then
        grep -v "^${var}=" "$WALK_STATE_ENV" > "$WALK_STATE_ENV.tmp" 2>/dev/null || true
        mv "$WALK_STATE_ENV.tmp" "$WALK_STATE_ENV"
      fi
      printf '%s=%q\n' "$var" "${!var}" >> "$WALK_STATE_ENV"
    fi
  done
}

# --- Poll-for-condition ------------------------------------------------

# wait_for <description> <shell-command> <timeout-seconds> [<poll-interval>]
# Polls until the command exits 0. Writes last output to $WALK_LOG on
# timeout. Returns 0 on success, 1 on timeout.
wait_for() {
  local desc="$1" cmd="$2" timeout="$3" interval="${4:-3}"
  local start="$SECONDS" last_out="" last_rc=1
  log "    waiting: $desc (≤${timeout}s, poll every ${interval}s)"
  while [ $((SECONDS - start)) -lt "$timeout" ]; do
    last_out="$(eval "$cmd" 2>&1)"; last_rc=$?
    if [ "$last_rc" -eq 0 ]; then
      log "    ✓ $desc ($((SECONDS - start))s)"
      return 0
    fi
    sleep "$interval"
  done
  log "    ✗ TIMEOUT after ${timeout}s waiting for: $desc"
  if [ -n "$last_out" ]; then
    log "      last output ($(echo "$last_out" | wc -l | tr -d ' ') lines, tail 5):"
    echo "$last_out" | tail -5 | sed 's/^/        /' | tee -a "$WALK_LOG"
  fi
  return 1
}

# wait_for_bead_label <rig-path> <label> <timeout> [<interval>]
# Succeeds when any bead in the rig has the expected label.
wait_for_bead_label() {
  local rig_path="$1" label="$2" timeout="$3" interval="${4:-8}"
  wait_for "any bead in rig labelled '$label'" \
    "cd '$rig_path' && bd list --label='$label' --json 2>/dev/null | jq -e 'length > 0' >/dev/null" \
    "$timeout" "$interval"
}

# wait_for_bead_closed <rig-path> <bead-id> <timeout> [<interval>]
wait_for_bead_closed() {
  local rig_path="$1" bead="$2" timeout="$3" interval="${4:-8}"
  wait_for "bead $bead closed" \
    "cd '$rig_path' && bd show '$bead' --json 2>/dev/null | jq -e '.status == \"closed\"' >/dev/null" \
    "$timeout" "$interval"
}

# --- Assertions --------------------------------------------------------

# assert_glob_nonempty <dir> <pattern> <description>
assert_glob_nonempty() {
  local dir="$1" pattern="$2" desc="$3"
  shopt -s nullglob
  local matches=( "$dir"/$pattern )
  shopt -u nullglob
  if [ "${#matches[@]}" -eq 0 ]; then
    step_fail "$desc — no file matches $dir/$pattern"
    return 1
  fi
  local first="${matches[0]}"
  if [ ! -s "$first" ]; then
    step_fail "$desc — file exists but is empty: $first"
    return 1
  fi
  step_pass "$desc → $first ($(wc -c <"$first" | tr -d ' ') bytes)"
}

# assert_artifact_has_sections <file> <section-header-regex>...
# Each regex must match at least one line in <file>.
assert_artifact_has_sections() {
  local file="$1"; shift
  if [ ! -s "$file" ]; then
    step_fail "$file — file missing or empty"
    return 1
  fi
  local missing=()
  local sect
  for sect in "$@"; do
    if ! grep -Eq "$sect" "$file"; then
      missing+=("$sect")
    fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    step_pass "$file has all required sections ($#)"
  else
    step_fail "$file missing sections: ${missing[*]}"
  fi
}

# --- Pre-flight helpers ------------------------------------------------

# Clean up any sfi-walkthrough-* cities left behind by prior killed runs.
purge_stranded_walkthrough_cities() {
  local stranded
  stranded="$(gc cities 2>/dev/null | awk '$1 ~ /^sfi-walkthrough-/ {print $2}')"
  if [ -z "$stranded" ]; then
    step_pass "no stranded sfi-walkthrough-* cities"
    return
  fi
  divergence "$WALK_LESSON_NAME" "found stranded sfi-walkthrough-* cities from prior runs; cleaning up"
  while IFS= read -r city_path; do
    [ -n "$city_path" ] || continue
    gc unregister "$city_path" >/dev/null 2>&1 || true
    log "    purged $city_path"
  done <<< "$stranded"
}

# Verify the tools a live-agent walkthrough needs.
assert_walkthrough_preflight() {
  assert_gc_version_ge_015
  if command -v claude >/dev/null 2>&1; then
    step_pass "claude CLI on PATH ($(command -v claude))"
  else
    step_fail "claude CLI not on PATH — install Claude Code before running"
  fi
  if claude auth status >/dev/null 2>&1; then
    step_pass "claude CLI authenticated"
  else
    step_fail "claude CLI not authenticated — run 'claude auth login'"
  fi
  local tool
  for tool in jq tmux git bd; do
    if command -v "$tool" >/dev/null 2>&1; then
      step_pass "$tool available"
    else
      step_fail "$tool not on PATH"
    fi
  done
}
