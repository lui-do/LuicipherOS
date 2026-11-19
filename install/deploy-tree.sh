#!/usr/bin/env bash
# install/deploy-tree.sh — publish the canonical tree to /opt/LuicipherOS.
#
# WHY: `lui` resolves $LUI_ROOT, then /opt/LuicipherOS, then its own tree, then
# ~/LuicipherOS. Without /opt, the admin account cannot read a clone in another
# user's home, and the daily account's bare `lui` has no tree to resolve. /opt is
# root-owned and world-readable, so both accounts (and future users) use one
# canonical, non-stale tree.
#
# Run as the admin account (luci), unprivileged; it escalates with sudo.
# IDEMPOTENT: rsync mirrors the source and removes stale files under /opt only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="/opt/LuicipherOS"
DRY=false

case "${1:-}" in
  --dry-run) DRY=true ;;
  -h|--help) echo "usage: $0 [--dry-run]"; exit 0 ;;
  "") : ;;
  *) echo "deploy-tree: unknown argument: $1" >&2; exit 2 ;;
esac

log() { echo "==> deploy-tree: $1"; }
command -v rsync >/dev/null || { echo "deploy-tree: rsync missing" >&2; exit 1; }

EXCLUDES=(
  --exclude .git
  --exclude .opencode
  --exclude .agent
  --exclude .agents
  --exclude screenshotVM
  --exclude out
  --exclude LinuxPanic
  --exclude memory
  --exclude 'MT86P_*'
  --exclude '*.jpg'
  --exclude 'docs/*.pdf'
  --exclude 'iso/pacman.conf'
  --exclude 'iso/syslinux'
  --exclude 'iso/efiboot'
)

log "source: $ROOT"
log "destination: $DEST$([[ "$DRY" == true ]] && echo ' (dry-run)')"

if [[ "$DRY" == true ]]; then
  sudo install -d -m755 "$DEST"
  sudo rsync -a --delete --dry-run "${EXCLUDES[@]}" "$ROOT/" "$DEST/"
  exit 0
fi

sudo install -d -m755 "$DEST"
sudo rsync -a --delete "${EXCLUDES[@]}" "$ROOT/" "$DEST/"
sudo chown -R root:root "$DEST"
sudo chmod -R a+rX "$DEST"

log "done; both accounts can now run: lui root"
log "update later by re-running this script from a fresh clone"