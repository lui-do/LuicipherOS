#!/usr/bin/env bash
# install/bootstrap.sh — fresh Arch -> LuicipherOS v0.1 (idempotent).
# Pipeline: preflight -> pacman/AUR lists -> stow dotfiles -> flatpaks
# -> enable services -> snapshot hint. Safe to re-run; every step skips
# work that is already done. Never prunes (removal lives in sync.sh --prune).
# CONTEXT.md: sync is manual-only. ADR-0001: Hyprland/lock/portals/drivers
# stay pacman-owned. Locked stack: Vicinae + fuzzel fallback, swaync,
# yay-bin, quickshell bar, tabby, system+user flatpak split.
# USAGE: ./install/bootstrap.sh [--aur-helper yay|paru] [--no-flatpak] [--stow-only] [--preflight-mode any|target|vm]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AUR_HELPER="yay"
NO_FLATPAK=false
STOW_ONLY=false
PREFLIGHT_MODE="any"
ARGS=("$@")
i=0
while [[ $i -lt $# ]]; do
  a="${ARGS[$i]}"
  case "$a" in
    --aur-helper)
      i=$((i+1)); AUR_HELPER="${ARGS[$i]:-yay}" ;;
    --aur-helper=*) AUR_HELPER="${a#*=}" ;;
    --no-flatpak) NO_FLATPAK=true ;;
    --stow-only) STOW_ONLY=true ;;
    --preflight-mode=*) PREFLIGHT_MODE="${a#*=}" ;;
    -h|--help)
      echo "Usage: $0 [--aur-helper yay|paru] [--no-flatpak] [--stow-only] [--preflight-mode any|target|vm]"
      exit 0
      ;;
    *) echo "WARN: unknown arg: $a" ;;
  esac
  i=$((i+1))
done

STOW_PKGS=(hypr quickshell swaync tabby fuzzel vicinae uwsm xdg)

log() { echo "==> $1"; }
need_cmd() { command -v "$1" &>/dev/null || { echo "FAIL: missing command: $1"; exit 1; }; }

log "LuicipherOS bootstrap v0.1 (helper=$AUR_HELPER, flatpak=$([ "$NO_FLATPAK" == true ] && echo off || echo on))"

# 1) preflight (fail fast on UEFI/network/disk; warns elsewhere).
# Strict: a --target/--vm failure aborts bootstrap (no fallback masking it).
case "$PREFLIGHT_MODE" in
  target) "$ROOT/install/preflight.sh" --target ;;
  vm)     "$ROOT/install/preflight.sh" --vm ;;
  *)      "$ROOT/install/preflight.sh" ;;
esac

if [[ "$STOW_ONLY" == true ]]; then
  log "stow-only mode: linking dotfiles"
else
  # 2) base packages (pacman + AUR, add-only)
  log "packages (add-only, no pruning)"
  if grep -q '^\[multilib\]' /etc/pacman.conf 2>/dev/null; then
    : # multilib already enabled
  elif grep -q '^\#\[multilib\]' /etc/pacman.conf 2>/dev/null; then
    log "enabling multilib (lib32 drivers need it)"
    sudo sed -i '/^\#\[multilib\]/,/^\#Include/s/^\#//' /etc/pacman.conf
    sudo pacman -Sy
  fi
  "$ROOT/scripts/ensure-packages.sh" --aur-helper "$AUR_HELPER"
fi

# 3) stow dotfiles -> $HOME (per-package layout: dotfiles/<pkg>/.config/...)
log "stow dotfiles (${STOW_PKGS[*]})"
need_cmd stow
mkdir -p "$HOME/.config"
for pkg in "${STOW_PKGS[@]}"; do
  if [[ -d "$ROOT/dotfiles/$pkg" ]]; then
    stow -d "$ROOT/dotfiles" -t "$HOME" --restow "$pkg"
    echo "  stowed: $pkg"
  else
    echo "  skip (no dir): $pkg"
  fi
done
# hyprland lua modules live under ~/.config/hypr/lua/ via hypr package
command -v hyprland &>/dev/null && echo "  hyprland: $(hyprland --version 2>/dev/null | head -1 || echo present)" \
  || echo "  NOTE: hyprland not yet installed (re-run bootstrap after packages land)"

if [[ "$STOW_ONLY" == true ]]; then
  log "stow-only done"
  exit 0
fi

# 4) flatpaks (split scopes; skipped with --no-flatpak, e.g. offline/VM)
if [[ "$NO_FLATPAK" == true ]]; then
  log "flatpak: skipped (--no-flatpak)"
else
  if command -v flatpak &>/dev/null; then
    log "flatpaks (system + user)"
    "$ROOT/scripts/ensure-flatpaks.sh"
  else
    echo "WARN: flatpak not installed yet — re-run bootstrap after packages land"
  fi
fi

# 5) services (opt-in enables; never auto-sync per CONTEXT.md locked decision)
log "enabling services (manual-only sync: no auto-sync units installed)"
sudo systemctl enable NetworkManager 2>/dev/null || echo "  (NetworkManager enable skipped/failed)"
sudo systemctl enable bluetooth 2>/dev/null || echo "  (bluetooth enable skipped — harmless on desktops without BT)"
sudo systemctl enable power-profiles-daemon 2>/dev/null || echo "  (power-profiles-daemon enable skipped)"
# user dirs + portals sanity
command -v xdg-user-dirs-update &>/dev/null && xdg-user-dirs-update || true

# 6) snapshot hint (ADR-0001 break prevention: snapshot before first sync)
echo ""
echo "--- post-bootstrap ---"
echo "  snapshot hint: sudo snapper -c root create --description 'luicipheros-bootstrap' \\"
echo "    || sudo timeshift --create --comments 'luicipheros-bootstrap'"
echo "  next: ./scripts/sync.sh            # add-only reconcile"
echo "  then: reboot -> Hyprland (uwsm) -> SUPER+Return tabby, SUPER+Space Vicinae"
echo "  verify: TESTING.md matrix (VM smoke, then target checklist)"
log "bootstrap done"
