#!/usr/bin/env bash
set -euo pipefail

phase="${1:-check}"
workspace_root="${FACTORY_WORKSPACE_ROOT:-$HOME/aitinkering}"
factory_slug="${FACTORY_REPO_SLUG:-deepkawal/software-factory-intensive}"
product_slug="${FACTORY_PRODUCT_REPO_SLUG:-deepkawal/ai-productivity}"
factory_repo="$workspace_root/software-factory-intensive"
product_repo="$workspace_root/ai-productivity-repo"
city_path="$factory_repo/my-factory"
rig_path="$product_repo/ai_meal_planner"
factory_pack="$product_repo/factory-skills/packs/core-factory"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
toolchain_file="$script_dir/../../../bootstrap/toolchain.env"
formula_dir="$script_dir/../../../bootstrap/homebrew"

require_wsl() {
  if ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
    echo "This installer must run inside Ubuntu on WSL 2." >&2
    exit 1
  fi
}

report_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    printf 'ok      %-10s %s\n' "$name" "$(command -v "$name")"
  else
    printf 'missing %-10s\n' "$name"
  fi
}

load_brew() {
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
}

installed_version() {
  case "$1" in
    gc) gc version | awk 'NR == 1 {print $1}' ;;
    bd) bd version | awk 'NR == 1 {print $3}' ;;
    dolt) dolt version | awk 'NR == 1 {print $3}' ;;
  esac
}

version_gate() {
  if [[ ! -f "$toolchain_file" ]]; then
    echo "Missing compatibility manifest: $toolchain_file" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source "$toolchain_file"

  local actual_gc actual_bd actual_dolt
  actual_gc="$(installed_version gc)"
  actual_bd="$(installed_version bd)"
  actual_dolt="$(installed_version dolt)"
  if [[ "$actual_gc" != "$GC_VERSION" || "$actual_bd" != "$BD_VERSION" || "$actual_dolt" != "$DOLT_VERSION" ]]; then
    echo "Toolchain mismatch; do not open or migrate shared Beads databases." >&2
    printf 'expected gc=%s bd=%s dolt=%s\n' "$GC_VERSION" "$BD_VERSION" "$DOLT_VERSION" >&2
    printf 'actual   gc=%s bd=%s dolt=%s\n' "$actual_gc" "$actual_bd" "$actual_dolt" >&2
    echo "Pin this host or coordinate an upgrade of both machines, then update bootstrap/toolchain.env." >&2
    exit 1
  fi
}

check() {
  require_wsl
  load_brew
  for command_name in git gh jq tmux flock lsof dolt bd gc claude codex; do
    report_command "$command_name"
  done
  printf 'workspace %s\n' "$workspace_root"
}

install_tools() {
  require_wsl
  echo "Human checkpoint: sudo may request the Ubuntu password."
  sudo apt-get update
  sudo apt-get install -y build-essential ca-certificates curl file git jq lsof procps tmux util-linux

  if ! command -v brew >/dev/null 2>&1 && [[ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  load_brew
  if ! brew tap | grep -qx 'local/factory'; then
    brew tap-new local/factory
  fi
  local_tap="$(brew --repository local/factory)"
  cp -f "$formula_dir/dolt.rb" "$local_tap/Formula/dolt.rb"
  cp -f "$formula_dir/beads.rb" "$local_tap/Formula/beads.rb"
  cp -f "$formula_dir/gascity.rb" "$local_tap/Formula/gascity.rb"
  brew install local/factory/dolt
  brew pin local/factory/dolt
  brew install local/factory/beads
  brew pin local/factory/beads
  brew install local/factory/gascity
  brew pin local/factory/gascity
  brew install gh node

  if ! command -v claude >/dev/null 2>&1; then
    curl -fsSL https://claude.ai/install.sh | bash
  fi
  if ! command -v codex >/dev/null 2>&1; then
    curl -fsSL https://chatgpt.com/codex/install.sh | sh
  fi

  check
  version_gate
  echo "Human checkpoint: run 'gh auth login', 'gh auth setup-git', 'claude', and 'codex'."
}

clone_if_missing() {
  local slug="$1"
  local destination="$2"
  if [[ -d "$destination/.git" ]]; then
    echo "Keeping existing clone: $destination"
    return
  fi
  if [[ -e "$destination" ]]; then
    echo "Refusing to overwrite non-Git path: $destination" >&2
    exit 1
  fi
  gh repo clone "$slug" "$destination"
}

install_skills() {
  local source_root="$city_path/skills"
  local skill_name skill_target skill_link_root
  mkdir -p "$HOME/.claude/skills" "$HOME/.agents/skills"
  for skill_name in factory-machine-bootstrap factory-manager; do
    for skill_link_root in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
      skill_target="$skill_link_root/$skill_name"
      if [[ -e "$skill_target" && ! -L "$skill_target" ]]; then
        echo "Refusing to replace existing skill directory: $skill_target" >&2
        exit 1
      fi
      ln -sfn "$source_root/$skill_name" "$skill_target"
    done
  done
}

configure_actor() {
  local machine_name="${FACTORY_MACHINE_NAME:-}"
  local actor_prefix="${FACTORY_ACTOR_PREFIX:-deepkawal}"
  local profile_line
  if [[ -z "$machine_name" ]]; then
    echo "Set FACTORY_MACHINE_NAME to a stable name such as machine-b." >&2
    exit 1
  fi
  if [[ ! "$machine_name" =~ ^[A-Za-z0-9._-]+$ || ! "$actor_prefix" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Factory machine name and actor prefix may contain only letters, digits, dot, underscore, and hyphen." >&2
    exit 1
  fi
  export BEADS_ACTOR="$actor_prefix-$machine_name"
  profile_line="export BEADS_ACTOR=$BEADS_ACTOR"
  if ! grep -Fqx "$profile_line" "$HOME/.profile" 2>/dev/null; then
    printf '\n# Software factory identity\n%s\n' "$profile_line" >>"$HOME/.profile"
  fi
}

configure_factory() {
  require_wsl
  load_brew
  version_gate
  configure_actor
  gh auth status
  mkdir -p "$workspace_root"
  clone_if_missing "$factory_slug" "$factory_repo"
  clone_if_missing "$product_slug" "$product_repo"

  hq_remote="${FACTORY_HQ_DOLT_REMOTE:-}"
  if [[ "$hq_remote" != git+https://* && "$hq_remote" != git+ssh://* ]]; then
    echo "Set FACTORY_HQ_DOLT_REMOTE to the dedicated private HQ state repository." >&2
    exit 1
  fi
  hq_git_url="${hq_remote#git+}"
  if ! git ls-remote "$hq_git_url" refs/dolt/data | grep -q 'refs/dolt/data'; then
    echo "Dedicated HQ remote does not expose refs/dolt/data: $hq_git_url" >&2
    exit 1
  fi
  echo "City Beads source: $hq_remote"
  echo "Product-rig Beads bootstrap plan:"
  (cd "$rig_path" && bd bootstrap --dry-run)
  if [[ "${FACTORY_ACCEPT_REMOTE_PLAN:-}" != "yes" ]]; then
    echo "Confirm the HQ ref above and verify the product plan will clone existing refs/dolt/data." >&2
    echo "Then rerun with FACTORY_ACCEPT_REMOTE_PLAN=yes." >&2
    exit 3
  fi

  if [[ ! -f "$city_path/.beads/metadata.json" ]]; then
    (cd "$city_path" && bd init --remote "$hq_remote" --prefix mf --non-interactive --skip-agents)
  else
    (cd "$city_path" && bd bootstrap --yes)
  fi
  (cd "$rig_path" && bd bootstrap --yes)

  cp -f "$city_path/pack.toml.template" "$city_path/pack.toml"
  cp -f "$city_path/bootstrap/city.toml.template" "$city_path/city.toml"
  install_skills

  gc init "$city_path" --file "$city_path/city.toml" --preserve-existing --skip-provider-readiness
  gc register "$city_path" --name my-factory

  rig_json="$(gc --city "$city_path" rig list --json)"
  if ! jq -e '.rigs | type == "array"' >/dev/null <<<"$rig_json"; then
    echo "Gas City returned an invalid rig list; refusing to mutate city.toml." >&2
    exit 1
  fi
  if ! jq -e '.rigs[]? | select(.name == "ai_meal_planner")' >/dev/null <<<"$rig_json"; then
    gc --city "$city_path" rig add "$rig_path" --adopt --start-suspended --name ai_meal_planner --prefix amp --default-branch main --include "$factory_pack"
  fi

  gc --city "$city_path" reload
  echo "The rig remains suspended. Verify sync from both machines before resuming it."
  echo "See: $city_path/skills/factory-machine-bootstrap/references/portable-state.md"
}

verify() {
  require_wsl
  load_brew
  check
  version_gate
  test -d "$city_path/.git"
  test -d "$product_repo/.git"
  test -f "$city_path/orders/beads-converge.toml"
  test -L "$HOME/.claude/skills/factory-manager"
  test -L "$HOME/.agents/skills/factory-manager"
  gc --city "$city_path" lint
  gc --city "$city_path" doctor
  bd -C "$city_path" doctor
  bd -C "$rig_path" doctor
  gc --city "$city_path" order show beads-converge
  gc --city "$city_path" config explain --rig ai_meal_planner
  gc start "$city_path" --dry-run
}

case "$phase" in
  check) check ;;
  install) install_tools ;;
  configure) configure_factory ;;
  verify) verify ;;
  *)
    echo "Usage: $0 {check|install|configure|verify}" >&2
    exit 2
    ;;
esac
