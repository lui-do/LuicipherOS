#!/usr/bin/env bash
# scripts/ensure-packages.sh — install missing pacman/AUR packages from lists (idempotent, add-only)
# IDEA: declarative ADD path. Never removes here; removal lives in sync.sh --prune.
# USAGE: ./scripts/ensure-packages.sh [--aur-helper yay|paru]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUR_HELPER="${1:-yay}"
[[ "${1:-}" == --aur-helper ]] && AUR_HELPER="${2:-yay}"

filter_list() {
  # strip comments + blanks
  grep -vE '^\s*#' "$1" | grep -vE '^\s*$' || true
}

# `lui ai disable` writes this flag; system sync must then skip the AI package
# set without editing the declarative lists (ADR-0002).
AI_DISABLED_FLAG="${LUI_AI_DISABLED_FLAG:-/etc/lui/ai.disabled}"
filter_ai() {
  if [[ -e "$AI_DISABLED_FLAG" && -f "$ROOT/config/ai-packages" ]]; then
    local excl; excl="$(mktemp)"
    filter_list "$ROOT/config/ai-packages" > "$excl"
    grep -vxF -f "$excl" || true
    rm -f "$excl"
  else
    cat
  fi
}

# Respect /etc/pacman.conf IgnorePkg/IgnoreGroup. Passing an ignored package to
# `pacman -S` overrides the pin (it prompts, and --noconfirm does not skip it),
# which is how the deliberately held linux-firmware pins were upgraded on
# 2026-11-19. Sync must never do that.
filter_ignored() {
  local ignored
  ignored="$(pacman-conf IgnorePkg 2>/dev/null | tr ' ' '\n' | grep -v '^$' || true)"
  if [[ -n "$ignored" ]]; then
    grep -vxF -f <(printf '%s\n' "$ignored") || true
  else
    cat
  fi
}

if [[ -e "$AI_DISABLED_FLAG" ]]; then
  echo "NOTE: AI stack disabled ($AI_DISABLED_FLAG); skipping config/ai-packages"
fi
IGNORED_PKGS="$(pacman-conf IgnorePkg 2>/dev/null | tr ' ' '\n' | grep -v '^$' || true)"
[[ -n "$IGNORED_PKGS" ]] && echo "NOTE: honoring IgnorePkg: $(echo "$IGNORED_PKGS" | tr '\n' ' ')"

echo "==> pacman: installing from config/packages"
if [[ -f "$ROOT/config/packages" ]]; then
  PKGS="$(filter_list "$ROOT/config/packages" | filter_ai | filter_ignored)"
  if [[ -n "$PKGS" ]]; then
    # shellcheck disable=SC2086
    sudo pacman -S --needed --noconfirm $PKGS
  else
    echo "  (nothing to install; all entries filtered/ignored)"
  fi
else
  echo "missing config/packages, skipping"
fi

echo "==> AUR: installing from config/packages-arch via $AUR_HELPER"
if [[ -f "$ROOT/config/packages-arch" ]]; then
  if ! command -v "$AUR_HELPER" &>/dev/null; then
    if [[ "$AUR_HELPER" == "yay" ]]; then
      # chicken-and-egg: yay-bin is installed via yay, so build it once
      # from the AUR directly (makepkg, no helper needed).
      echo "==> bootstrapping yay (git + makepkg, one time)"
      TMPD="$(mktemp -d)"
      git clone https://aur.archlinux.org/yay-bin.git "$TMPD/yay-bin"
      (cd "$TMPD/yay-bin" && makepkg -si --noconfirm)
      rm -rf "$TMPD"
    else
      echo "WARN: $AUR_HELPER not found and no auto-bootstrap for it (only yay); install $AUR_HELPER first"
    fi
  fi
  if command -v "$AUR_HELPER" &>/dev/null; then
    # yay v13+: menus are skipped via --answer* None (the old --no*menu flags
    # are gone; without these, existing build files hang even --noconfirm).
    # NOTE: answer any PGP key import prompt by hand (no safe flag for it).
    AUR_PKGS="$(filter_list "$ROOT/config/packages-arch" | filter_ai | filter_ignored)"
    if [[ -n "$AUR_PKGS" ]]; then
      # shellcheck disable=SC2086
      "$AUR_HELPER" -S --needed --noconfirm --answerclean None --answerdiff None --answeredit None --cleanafter $AUR_PKGS
    else
      echo "  (nothing to install; all AUR entries filtered/ignored)"
    fi
  else
    echo "WARN: $AUR_HELPER still missing, skipping AUR"
  fi
fi
echo "==> packages OK (add-only, no pruning)"
