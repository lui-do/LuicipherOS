#!/usr/bin/env bash
# scripts/sync.sh — LuicipherOS declarative reconciler (v0.1, "luci sync")
# IDEA: single entry point for "edit lists -> get system".
# - `luci sync` (default): INSTALL missing only. Safe to run anytime, safe on boot.
# - `luci sync --prune`: install missing + UNINSTALL extras not in lists (with confirm + protected guard).
#   - pacman extras = (explicitly installed) - (desired + protected). Deps (-Qqd) are NEVER touched.
#   - flatpak extras = (installed apps) - (desired app IDs).
# - v0.1 LOCKED: manual-only (grill Q5). No systemd auto-sync; run by hand.
# USAGE: ./scripts/sync.sh [--prune] [--dry-run] [--yes]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRUNE=false; DRY_RUN=false; YES=false
for a in "$@"; do
  case "$a" in
    --prune) PRUNE=true ;;
    --dry-run) DRY_RUN=true ;;
    --yes|-y) YES=true ;;
  esac
done

echo "=== luci sync (v0.1, manual-only) ==="
if [[ "$DRY_RUN" == true ]]; then echo "(dry-run: no changes will be made)"; fi

# 1) ADD path (always, both scopes)
if [[ "$DRY_RUN" == false ]]; then
  "$ROOT/scripts/ensure-packages.sh"
  "$ROOT/scripts/ensure-flatpaks.sh"
  echo "==> flatpak update + cleanup unused runtimes (system + user)"
  flatpak update -y --system || true
  flatpak update -y --user || true
  flatpak uninstall --unused -y --system || true
  flatpak uninstall --unused -y --user || true
else
  echo "[dry-run] would run ensure-packages.sh + ensure-flatpaks.sh (system+user)"
fi

# 2) PRUNE path (opt-in only)
if [[ "$PRUNE" == false ]]; then
  echo "=== done (add-only). Re-run with --prune to remove extras not in lists. ==="
  exit 0
fi

echo "=== prune preview (extras NOT in lists) ==="
# --- pacman extras ---
mapfile -t DESIRED < <(cat "$ROOT/config/packages" "$ROOT/config/packages-arch" 2>/dev/null | grep -vE '^\s*#' | grep -vE '^\s*$' | sort -u || true)
mapfile -t PROTECTED < <(cat "$ROOT/config/protected-packages" 2>/dev/null | grep -vE '^\s*#' | grep -vE '^\s*$' | sort -u || true)
mapfile -t EXPLICIT < <(pacman -Qqe | sort -u || true)
# build lookup
declare -A KEEP=()
for p in "${DESIRED[@]}" "${PROTECTED[@]}"; do KEEP["$p"]=1; done
PACMAN_EXTRAS=()
for p in "${EXPLICIT[@]}"; do [[ -z "${KEEP[$p]:-}" ]] && PACMAN_EXTRAS+=("$p"); done
echo "pacman extras (${#PACMAN_EXTRAS[@]}): ${PACMAN_EXTRAS[*]:-(none)}"

# --- flatpak extras (split scopes) ---
desired_fp_file() {
  cat "$ROOT/config/flatpaks-system.list" "$ROOT/config/flatpaks-user.list" "$ROOT/config/flatpaks.list" 2>/dev/null \
    | grep -vE '^\s*#' | grep -vE '^\s*$' | awk '{print $2}' | sort -u || true
}
mapfile -t DESIRED_FP < <(desired_fp_file)
mapfile -t INSTALLED_SYS < <(flatpak list --system --app --columns=application 2>/dev/null | sort -u || true)
mapfile -t INSTALLED_USR < <(flatpak list --user --app --columns=application 2>/dev/null | sort -u || true)
declare -A KEEP_FP=()
for a in "${DESIRED_FP[@]}"; do KEEP_FP["$a"]=1; done
FP_SYS_EXTRAS=(); FP_USR_EXTRAS=()
for a in "${INSTALLED_SYS[@]}"; do [[ -z "${KEEP_FP[$a]:-}" ]] && FP_SYS_EXTRAS+=("$a"); done
for a in "${INSTALLED_USR[@]}"; do [[ -z "${KEEP_FP[$a]:-}" ]] && FP_USR_EXTRAS+=("$a"); done
echo "flatpak system extras (${#FP_SYS_EXTRAS[@]}): ${FP_SYS_EXTRAS[*]:-(none)}"
echo "flatpak user extras (${#FP_USR_EXTRAS[@]}): ${FP_USR_EXTRAS[*]:-(none)}"

if [[ ${#PACMAN_EXTRAS[@]} -eq 0 && ${#FP_SYS_EXTRAS[@]} -eq 0 && ${#FP_USR_EXTRAS[@]} -eq 0 ]]; then
  echo "=== nothing to prune ==="; exit 0
fi
if [[ "$DRY_RUN" == true ]]; then echo "=== dry-run, stopping before removal ==="; exit 0; fi
if [[ "$YES" == false ]]; then
  read -r -p "Remove above extras? [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "aborted"; exit 1; }
fi
if [[ ${#PACMAN_EXTRAS[@]} -gt 0 ]]; then
  echo "==> removing pacman extras (explicit only, deps untouched)"
  sudo pacman -Rns --noconfirm "${PACMAN_EXTRAS[@]}"
fi
if [[ ${#FP_SYS_EXTRAS[@]} -gt 0 ]]; then
  echo "==> removing flatpak system extras"
  flatpak uninstall -y --system "${FP_SYS_EXTRAS[@]}"
fi
if [[ ${#FP_USR_EXTRAS[@]} -gt 0 ]]; then
  echo "==> removing flatpak user extras"
  flatpak uninstall -y --user "${FP_USR_EXTRAS[@]}"
fi
echo "=== sync --prune complete ==="
