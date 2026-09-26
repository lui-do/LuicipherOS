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

echo "==> pacman: installing from config/packages"
if [[ -f "$ROOT/config/packages" ]]; then
  # shellcheck disable=SC2046
  sudo pacman -S --needed --noconfirm $(filter_list "$ROOT/config/packages")
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
    # shellcheck disable=SC2046
    "$AUR_HELPER" -S --needed --noconfirm $(filter_list "$ROOT/config/packages-arch")
  else
    echo "WARN: $AUR_HELPER still missing, skipping AUR"
  fi
fi
echo "==> packages OK (add-only, no pruning)"
