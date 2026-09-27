#!/usr/bin/env bash
set -euo pipefail

city_path="${GC_CITY_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
lock_path="$city_path/.gc/beads-converge.lock"

mkdir -p "$city_path/.gc"
exec 9>"$lock_path"
if ! flock -n 9; then
  echo "Beads convergence is already running; skipping this cycle."
  exit 0
fi

commit_store() {
  local store_path="$1"
  bd -C "$store_path" dolt commit -m "automatic cross-machine checkpoint"
}

commit_store "$city_path"

rig_json="$(gc --city "$city_path" rig list --json)"
if ! jq -e '.rigs | type == "array"' >/dev/null <<<"$rig_json"; then
  echo "Gas City returned an invalid rig list; refusing a partial sync." >&2
  exit 1
fi
rig_paths="$(jq -r '.rigs[]?.path' <<<"$rig_json")"
while IFS= read -r rig_path; do
  if [[ -n "$rig_path" && -d "$rig_path/.beads" ]]; then
    commit_store "$rig_path"
  fi
done <<<"$rig_paths"

(
  cd "$city_path"
  gc dolt pull
  gc dolt sync
)
