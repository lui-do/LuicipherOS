#!/usr/bin/env bash
# install/bootstrap.sh — fresh Arch -> LuicipherOS v0.1 (stub, idempotent)
# IDEA: preflight -> pacman lists -> stow dotfiles -> flatpaks -> enable services.
# Mirrors Omarchy/ML4W pipeline without tracking upstream. Flesh in grill.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/install/preflight.sh"
"$ROOT/scripts/ensure-packages.sh"
stow -d "$ROOT/dotfiles" -t "$HOME/.config" --restow . 2>/dev/null || echo "TODO: add dotfiles/hypr + stow layout in grill"
"$ROOT/scripts/sync.sh"
sudo systemctl enable NetworkManager bluetooth power-profiles-daemon || true
echo "bootstrap done (stub)"
