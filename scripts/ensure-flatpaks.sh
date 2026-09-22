#!/usr/bin/env bash
# scripts/ensure-flatpaks.sh — install missing Flatpaks from split lists (idempotent, add-only)
# IDEA: system-wide + user-only split (grill Q4 = divide).
# - config/flatpaks-system.list -> flatpak --system (needs sudo, shared apps)
# - config/flatpaks-user.list -> flatpak --user (no sudo, personal apps)
# - Legacy config/flatpaks.list still honored as system scope if present (compat).
# - Removal lives in sync.sh --prune, NOT here.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ensure_list() {
  local list="$1" scope="$2"
  [[ -f "$list" ]] || return 0
  while read -r remote app branch; do
    [[ "${remote:-}" =~ ^#.*$ || -z "${remote:-}" ]] && continue
    [[ "${app:-}" =~ ^#.*$ || -z "${app:-}" ]] && continue
    branch="${branch:-stable}"
    if [[ "$remote" == "flathub" ]]; then
      flatpak remote-add --if-not-exists "$scope" flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi
    if ! flatpak info "$scope" "$app" &>/dev/null; then
      echo "==> installing $app ($remote:$branch) [$scope]"
      flatpak install -y "$scope" "$remote" "$app"//"$branch"
    fi
  done < <(grep -vE '^\s*#' "$list" | grep -vE '^\s*$' || true)
}

ensure_list "$ROOT/config/flatpaks-system.list" "--system"
ensure_list "$ROOT/config/flatpaks-user.list" "--user"
# compat: old single list = system scope
if [[ -f "$ROOT/config/flatpaks.list" ]]; then
  echo "NOTE: config/flatpaks.list is legacy; migrate lines into flatpaks-system/user lists"
  ensure_list "$ROOT/config/flatpaks.list" "--system"
fi
