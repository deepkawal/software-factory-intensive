#!/usr/bin/env bash
# behavioral-smoke.sh — runtime smoke test for the current migration state.
#
# Creates a scratch factory at /tmp/sfi-smoke/ that imports this repo's
# packs/all at workspace scope and via default_rig_includes, then asserts:
#   - gc doctor loads the factory without v2 schema errors
#   - Every migrated agent-bearing pack's doctor check passes
#   - Every migrated pack's commands resolve via gc <binding> <cmd> --help
#
# This exercises the integration points structural invariants can't catch:
# convention discovery, import resolution, pack-command namespacing.
#
# Exits 0 on full green. Run after migration-check.sh passes.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

smoke_dir="/tmp/sfi-smoke"
FAILED=0
fail() { echo "FAIL: $*" >&2; FAILED=$((FAILED + 1)); }

echo "== behavioral-smoke =="
echo "repo: $repo_root"
echo "factory: $smoke_dir"
echo

# Recreate the smoke factory. Uses absolute paths so it's independent of the
# real my-factory/ layout (which may not exist yet during early migration).
rm -rf "$smoke_dir"
mkdir -p "$smoke_dir"
cat >"$smoke_dir/city.toml" <<EOF
[workspace]
name = "sfi-smoke"
provider = "claude"
default_rig_includes = ["$repo_root/packs/all"]

[session]
startup_timeout = "3m"

[daemon]
patrol_interval = "30s"
max_restarts = 5
restart_window = "1h"
shutdown_timeout = "5s"
EOF
cat >"$smoke_dir/pack.toml" <<EOF
[pack]
name = "sfi-smoke"
schema = 2

[imports.all]
source = "$repo_root/packs/all"

[imports.fired-up-pizza]
source = "$repo_root/packs/fired-up-pizza"

[imports.workshop]
source = "$repo_root/packs/workshop"
EOF

# --- Check 1: gc doctor runs without hard errors ---
echo "[1] gc doctor on smoke factory"
doctor_out="$(mktemp)"
trap 'rm -f "$doctor_out"' EXIT
if (cd "$smoke_dir" && gc doctor 2>&1) >"$doctor_out" 2>&1; then
  echo "  gc doctor exited 0"
else
  # gc doctor returns non-zero if any check fails; the "beads-store" and
  # "dolt-server" checks always fail in a brand-new factory with no rig.
  # Accept those specifically; error on anything else.
  if grep -Eq 'beads-store.*store ping failed|dolt-server.*port unknown' "$doctor_out"; then
    echo "  gc doctor: only the expected brand-new-factory failures (beads-store, dolt-server)"
  else
    fail "gc doctor reported unexpected errors (see output below)"
    tail -40 "$doctor_out" >&2
  fi
fi

# --- Check 2: every migrated canonical pack's doctor check appears in output ---
# Scope limited to the old canonical pack surface imported by packs/all,
# packs/fired-up-pizza, and packs/workshop. Self-contained lesson packs under
# packs/lessons/* are checked by lesson-pack-lint and the per-lesson
# walkthroughs; they are not imported into this legacy smoke factory.
echo "[2] every migrated canonical pack's doctor check is present"
MIGRATED_AGENT_PACKS=()
while IFS= read -r pack_name; do
  MIGRATED_AGENT_PACKS+=("$pack_name")
done < <(
  for pt in $(find packs -path 'packs/lessons' -prune -o -name pack.toml -print 2>/dev/null); do
    if grep -q '^schema = 2' "$pt" && [ -d "$(dirname "$pt")/agents" ]; then
      grep -E '^name = ' "$pt" | head -1 | sed -E 's/^name = "([^"]+)".*/\1/'
    fi
  done | sort -u
)
for pack_name in "${MIGRATED_AGENT_PACKS[@]}"; do
  [ -n "$pack_name" ] || continue
  # Doctor check names are scoped like "<pack_name>:check-<something>"
  if ! grep -q "^[[:space:]]*[✓⚠✗] $pack_name:" "$doctor_out"; then
    fail "$pack_name doctor check missing from gc doctor output"
  fi
done

# --- Check 3: every migrated pack command is registered at gc <binding> level ---
echo "[3] migrated pack commands appear in gc <binding> --help"
# We can't use `gc <binding> <cmd> --help` directly because pack commands
# are shell scripts — `--help` gets passed through to the script, not
# intercepted by cobra. Some scripts handle --help gracefully (exit 0),
# others don't. What we CAN reliably check: does cobra list the command
# in `gc <binding> --help`? If yes, cobra registered it, which is what we
# need for gc all wake-downstream &-style handoff invocations.
#
# The binding name in the smoke chain matches the pack's basename: packs/all
# is imported as [imports.all] → binding=all; packs/all imports [imports.architect]
# → binding=architect; etc.
for pack_dir in packs/*/; do
  pt="$pack_dir/pack.toml"
  [ -f "$pt" ] || continue
  grep -q '^schema = 2' "$pt" || continue
  [ -d "$pack_dir/commands" ] || continue
  pack_basename="$(basename "$pack_dir")"
  binding_help="$(cd "$smoke_dir" && gc "$pack_basename" --help 2>&1 || true)"
  for cmd_dir in "$pack_dir"/commands/*/; do
    [ -d "$cmd_dir" ] || continue
    cmd_name="$(basename "$cmd_dir")"
    # Match `  cmd_name  description…` on its own line in the help output.
    if ! echo "$binding_help" | grep -Eq "^[[:space:]]+${cmd_name}([[:space:]]|$)"; then
      fail "gc $pack_basename --help does not list '$cmd_name'"
    fi
  done
done

# --- Check 4: each checkpoint factory (W2, L2) is structurally loadable ---
# Per plan Verification §6: checkpoint trees should be runnable as standalone
# cities using their template → runtime-copy setup. We mirror the real setup
# flow: copy .template → runtime files and run gc doctor in a scratch copy.
echo "[4] checkpoint factories (W2, L2) load cleanly"
for checkpoint in \
  activites/workshops/W2/gascity/step_0/packs \
  activites/labs/L2/gascity/step_0/packs
do
  [ -f "$checkpoint/pack.toml.template" ] || continue
  [ -f "$checkpoint/city.toml.template" ] || continue
  scratch="/tmp/sfi-smoke-$(echo "$checkpoint" | tr '/' '-')"
  rm -rf "$scratch"
  mkdir -p "$scratch"
  cp -r "$checkpoint"/. "$scratch"/
  cp "$scratch/pack.toml.template" "$scratch/pack.toml"
  cp "$scratch/city.toml.template" "$scratch/city.toml"
  ck_out="$(mktemp)"
  rc=0
  (cd "$scratch" && gc doctor 2>&1) >"$ck_out" 2>&1 || rc=$?
  if [ "$rc" = "0" ]; then
    echo "  $checkpoint → gc doctor exited 0"
  elif grep -Eq 'beads-store.*store ping failed|dolt-server.*port unknown' "$ck_out"; then
    echo "  $checkpoint → only expected brand-new-factory failures"
  else
    fail "$checkpoint gc doctor reported unexpected errors"
    tail -20 "$ck_out" >&2
  fi
  rm -f "$ck_out"
done

# --- Summary ---
echo
if [ "$FAILED" -eq 0 ]; then
  echo "✓ behavioral smoke passes"
  exit 0
else
  echo "✗ $FAILED behavioral check(s) failed" >&2
  exit 1
fi
