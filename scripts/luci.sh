#!/usr/bin/env bash
# scripts/luci.sh — LuicipherOS CLI ("luci").
#
# Single user-facing entry point. Installed to /usr/local/bin/luci by
# install/bootstrap.sh, and runnable in place from the repo.
#
# v0.1 subcommands:
#   luci sync [--prune] [--dry-run] [--yes]  reconcile packages + flatpaks
#   luci status                              read-only: what is out of sync
#   luci root                                print the resolved tree path
#   luci version | help
#
# The tree is located at runtime, in this order:
#   1. $LUCI_ROOT
#   2. /opt/LuicipherOS      (shared system tree; see the multi-user plan)
#   3. the tree this script lives in (running in place from a clone)
#   4. $HOME/LuicipherOS     (per-user clone, current default)
#
# Order matters: an installed copy at /usr/local/bin/luci is not inside a tree,
# so it falls through to the shared or per-user location. Running the script
# from inside a clone means that clone.
#
# LOCKED (ADR-0001, grill Q5): sync is manual-only. This CLI never installs a
# timer, unit or hook that reconciles on boot or on a schedule.
set -euo pipefail

LUCI_VERSION="0.1"

die() { printf 'luci: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
luci — LuicipherOS declarative reconciler

USAGE
  luci sync [--prune] [--dry-run] [--yes]   install missing packages + flatpaks
  luci status                               read-only preview of what would change
  luci root                                 print the resolved LuicipherOS tree
  luci version                              print the CLI version
  luci help                                 this text

SYNC
  Default is add-only: installs what the lists declare, never removes.
    --prune     also remove extras not declared in the lists (asks first)
    --dry-run   preview only; change nothing
    --yes       skip the confirmation prompt (automation only)

  Prune honors config/protected-packages and never touches pacman
  dependencies (-Qqd). System and user flatpak scopes are handled separately.

NOTES
  Run as your normal user, not root: luci calls sudo itself for the
  privileged steps. Sync is manual-only by design; there is no auto-sync
  unit and none will be installed.
EOF
}

resolve_root() {
  local cand self
  if [[ -n "${LUCI_ROOT:-}" ]]; then
    [[ -f "$LUCI_ROOT/scripts/sync.sh" ]] \
      || die "LUCI_ROOT=$LUCI_ROOT does not look like a LuicipherOS tree"
    printf '%s\n' "$LUCI_ROOT"; return 0
  fi
  for cand in /opt/LuicipherOS; do
    if [[ -f "$cand/scripts/sync.sh" ]]; then printf '%s\n' "$cand"; return 0; fi
  done
  self="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [[ -f "$self/scripts/sync.sh" ]]; then printf '%s\n' "$self"; return 0; fi
  cand="$HOME/LuicipherOS"
  if [[ -f "$cand/scripts/sync.sh" ]]; then printf '%s\n' "$cand"; return 0; fi
  die "cannot locate the LuicipherOS tree (set LUCI_ROOT, or clone to ~/LuicipherOS)"
}

# The reconciler calls sudo internally; running the whole CLI as root would
# make every pacman/flatpak action root-owned and is forbidden by AGENTS.md.
[[ "${EUID:-$(id -u)}" -eq 0 ]] \
  && die "do not run luci as root; run it as your user (it calls sudo itself)"

cmd="${1:-help}"
[[ $# -gt 0 ]] && shift

case "$cmd" in
  sync)
    ROOT="$(resolve_root)"
    exec "$ROOT/scripts/sync.sh" "$@"
    ;;
  status)
    # Read-only: sync.sh's prune preview changes nothing and lists exactly
    # the extras. Reusing it keeps one implementation of the diff logic.
    ROOT="$(resolve_root)"
    exec "$ROOT/scripts/sync.sh" --prune --dry-run "$@"
    ;;
  root)
    resolve_root
    ;;
  version|--version|-V)
    printf 'luci %s\n' "$LUCI_VERSION"
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    printf 'luci: unknown subcommand: %s\n\n' "$cmd" >&2
    usage >&2
    exit 2
    ;;
esac
