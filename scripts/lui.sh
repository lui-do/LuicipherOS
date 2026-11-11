#!/usr/bin/env bash
# scripts/lui.sh — LuicipherOS CLI ("lui").
#
# Single user-facing entry point. Installed to /usr/local/bin/lui by
# install/bootstrap.sh, and runnable in place from the repo.
#
# v0.1 subcommands:
#   lui sync [--prune] [--dry-run] [--yes]  reconcile packages + flatpaks
#   lui status                              read-only: what is out of sync
#   lui root                                print the resolved tree path
#   lui version | help
#
# The tree is located at runtime, in this order:
#   1. $LUI_ROOT
#   2. /opt/LuicipherOS      (shared system tree; see the multi-user plan)
#   3. the tree this script lives in (running in place from a clone)
#   4. $HOME/LuicipherOS     (per-user clone — see the staleness warning below)
#
# Order matters: an installed copy at /usr/local/bin/lui is not inside a tree,
# so it falls through to the shared or per-user location.
#
# WHY THE FALLBACK WARNS: a per-user clone can be arbitrarily stale. `--prune`
# computes extras as (installed - declared), so a stale tree makes every package
# declared since that clone was last pulled look like an extra, and pruning then
# removes real packages. This is not hypothetical: on 2026-11-11 the admin
# account's stale clone reported 21 false extras, all of them declared in the
# canonical tree. Always reconcile from ONE canonical tree.
#
# LOCKED (ADR-0001, grill Q5): sync is manual-only. This CLI never installs a
# timer, unit or hook that reconciles on boot or on a schedule.
set -euo pipefail

LUI_VERSION="0.1"

die() { printf 'lui: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
lui — LuicipherOS declarative reconciler

USAGE
  lui sync [--prune] [--dry-run] [--yes]   install missing packages + flatpaks
  lui status                               read-only preview of what would change
  lui root                                 print the resolved LuicipherOS tree
  lui version                              print the CLI version
  lui help                                 this text

SYNC
  Default is add-only: installs what the lists declare, never removes.
    --prune     also remove extras not declared in the lists (asks first)
    --dry-run   preview only; change nothing
    --yes       skip the confirmation prompt (automation only)

  Prune honors config/protected-packages and never touches pacman
  dependencies (-Qqd). System and user flatpak scopes are handled separately.

TREE SELECTION
  luci resolves the tree via $LUI_ROOT, then /opt/LuicipherOS, then the tree
  this script lives in, then ~/LuicipherOS. Because --prune is destructive,
  check `lui root` and the `tree:` line before pruning: a stale clone makes
  declared packages look like extras.

NOTES
  Run as your normal user, not root: lui calls sudo itself for the privileged
  steps. Sync is manual-only by design; there is no auto-sync unit and none
  will be installed.
EOF
}

resolve_root() {
  local cand self
  if [[ -n "${LUI_ROOT:-}" ]]; then
    [[ -f "$LUI_ROOT/scripts/sync.sh" ]] \
      || die "LUI_ROOT=$LUI_ROOT does not look like a LuicipherOS tree"
    printf '%s\n' "$LUI_ROOT"; return 0
  fi
  cand="/opt/LuicipherOS"
  if [[ -f "$cand/scripts/sync.sh" ]]; then printf '%s\n' "$cand"; return 0; fi
  self="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  if [[ -f "$self/scripts/sync.sh" ]]; then printf '%s\n' "$self"; return 0; fi
  cand="$HOME/LuicipherOS"
  if [[ -f "$cand/scripts/sync.sh" ]]; then printf '%s\n' "$cand"; return 0; fi
  die "cannot locate the LuicipherOS tree (set LUI_ROOT, or clone to ~/LuicipherOS)"
}

# Which rule selected the tree; used to warn on the risky per-user fallback.
classify_root() { # $1 = resolved root
  if [[ -n "${LUI_ROOT:-}" ]]; then echo "LUI_ROOT"
  elif [[ "$1" == "/opt/LuicipherOS" ]]; then echo "shared"
  elif [[ "$1" == "$HOME/LuicipherOS" ]]; then echo "home-fallback"
  else echo "in-place"
  fi
}

# $1 = root, $2 = source, $3 = "prune" when the operation is destructive.
# The banner is always shown. The warning is shown only for --prune: a stale
# tree is harmless for the add-only path and only dangerous when removing.
tree_banner() {
  local head=""
  if command -v git >/dev/null 2>&1; then
    head="$(git -C "$1" rev-parse --short HEAD 2>/dev/null || true)"
  fi
  printf 'tree: %s%s [%s]\n' "$1" "${head:+ @ $head}" "$2"
  [[ "$3" == "prune" && "$2" == "home-fallback" ]] || return 0
  cat >&2 <<'WARN'

WARNING: this is this user's own clone (~/LuicipherOS), which may be stale.
         --prune computes extras as (installed - declared), so a stale tree
         makes every package declared since the last pull look like an extra
         and would remove it. Check `lui root` first; if this is not the
         canonical tree, run instead:
             LUI_ROOT=/path/to/canonical/tree lui sync --prune
WARN
}

# True when --prune is among the delegated arguments.
is_prune() { for a in "$@"; do [[ "$a" == "--prune" ]] && return 0; done; return 1; }

# The reconciler calls sudo internally; running the whole CLI as root would
# make every pacman/flatpak action root-owned and is forbidden by AGENTS.md.
[[ "${EUID:-$(id -u)}" -eq 0 ]] \
  && die "do not run lui as root; run it as your user (it calls sudo itself)"

cmd="${1:-help}"
[[ $# -gt 0 ]] && shift

case "$cmd" in
  sync)
    ROOT="$(resolve_root)"
    MODE=safe; is_prune "$@" && MODE=prune
    tree_banner "$ROOT" "$(classify_root "$ROOT")" "$MODE"
    exec "$ROOT/scripts/sync.sh" "$@"
    ;;
  status)
    # Read-only: sync.sh's prune preview changes nothing and lists exactly
    # the extras. Reusing it keeps one implementation of the diff logic.
    ROOT="$(resolve_root)"
    # status is a prune preview, but it never removes, so it stays a "safe"
    # operation and gets the banner without the destructive-path warning.
    tree_banner "$ROOT" "$(classify_root "$ROOT")" safe
    exec "$ROOT/scripts/sync.sh" --prune --dry-run "$@"
    ;;
  root)
    resolve_root
    ;;
  version|--version|-V)
    printf 'lui %s\n' "$LUI_VERSION"
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    printf 'lui: unknown subcommand: %s\n\n' "$cmd" >&2
    usage >&2
    exit 2
    ;;
esac
