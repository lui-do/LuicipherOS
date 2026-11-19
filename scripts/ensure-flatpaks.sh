#!/usr/bin/env bash
# scripts/ensure-flatpaks.sh — install missing Flatpaks from split lists (idempotent, add-only)
# IDEA: system-wide + user-only split (grill Q4 = divide).
# - config/flatpaks-system.list -> flatpak --system (needs admin/polkit, shared apps)
# - config/flatpaks-user.list -> flatpak --user (no sudo, personal apps)
# - Legacy config/flatpaks.list still honored as system scope if present (compat).
# - Removal lives in sync.sh --prune, NOT here.
#
# SCOPES (multi-user split, ADR-0002):
#   --system   only the system list (admin account)
#   --user     only the user list (invoking account)
#   (no flag)  both, for backwards compatibility
# USAGE: scripts/ensure-flatpaks.sh [--system|--user]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SCOPE=both
case "${1:-}" in
  --system) SCOPE=system ;;
  --user)   SCOPE=user ;;
  -h|--help) echo "usage: $0 [--system|--user]"; exit 0 ;;
  "") : ;;
  *) echo "ensure-flatpaks: unknown argument: $1" >&2; exit 2 ;;
esac

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

if [[ "$SCOPE" == "system" || "$SCOPE" == "both" ]]; then
  ensure_list "$ROOT/config/flatpaks-system.list" "--system"
  # compat: old single list = system scope
  if [[ -f "$ROOT/config/flatpaks.list" ]]; then
    echo "NOTE: config/flatpaks.list is legacy; migrate lines into flatpaks-system/user lists"
    ensure_list "$ROOT/config/flatpaks.list" "--system"
  fi
fi

if [[ "$SCOPE" == "user" || "$SCOPE" == "both" ]]; then
  ensure_list "$ROOT/config/flatpaks-user.list" "--user"
fi