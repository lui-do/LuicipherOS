#!/usr/bin/env bash
# scripts/sync.sh — LuicipherOS declarative reconciler (v0.1, "lui sync")
# IDEA: single entry point for "edit lists -> get system".
#
# SCOPES (added 2026-11-19, ADR-0002 multi-user split):
#   --system        system-wide: pacman + AUR packages, system flatpaks and
#                   system services. Requires an admin account (luci).
#   --user [USER]   one account's user scope: user flatpaks + launcher entries.
#                   Defaults to the invoking user. Naming another account needs
#                   admin rights (runs as that user via sudo -u).
#   (no flag)       system + current user when admin rights are available;
#                   otherwise user scope only, with the exact --system command
#                   to run as the admin.
#
# MODIFIERS:
#   --prune         remove extras inside the selected scopes (asks first)
#   --dry-run       preview only; change nothing
#   --yes           skip the confirmation prompt (automation only)
#
# Locked v0.1 behaviour: manual-only, no auto-sync unit. Prune never touches
# pacman dependencies (-Qqd) and never removes config/protected-packages.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PRUNE=false; DRY_RUN=false; YES=false
SCOPE=""            # system | user | both
TARGET_USER=""      # only meaningful with --user
CURRENT_USER="$(id -un)"

die() { printf 'sync: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
usage: lui sync [--system | --user [USER]] [--prune] [--dry-run] [--yes]

  --system       system-wide packages + system flatpaks (admin account, e.g. luci)
  --user [USER]  user flatpaks + launcher entries (default: this account)
  --prune        remove extras inside the selected scopes (asks first)
  --dry-run      preview only
  --yes          skip the confirmation prompt (automation only)
EOF
}

while [[ $# -gt 0 ]]; do
  a="$1"; shift
  case "$a" in
    --prune) PRUNE=true ;;
    --dry-run) DRY_RUN=true ;;
    --yes|-y) YES=true ;;
    --system)
      [[ "$SCOPE" == "user" ]] && die "--system and --user are mutually exclusive"
      SCOPE=system ;;
    --user)
      [[ "$SCOPE" == "system" ]] && die "--system and --user are mutually exclusive"
      SCOPE=user
      # optional account name, but never swallow another flag
      if [[ $# -gt 0 && "$1" != -* ]]; then TARGET_USER="$1"; shift; fi ;;
    --user=*)
      [[ "$SCOPE" == "system" ]] && die "--system and --user are mutually exclusive"
      SCOPE=user; TARGET_USER="${a#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $a (see: lui sync --help)" ;;
  esac
done

[[ "$SCOPE" == "system" && -n "$TARGET_USER" ]] \
  && die "--system does not take a user; use --user USER for a user scope"

# Resolve the account that owns the user scope.
[[ -n "$TARGET_USER" ]] || TARGET_USER="$CURRENT_USER"
getent passwd "$TARGET_USER" >/dev/null 2>&1 \
  || die "unknown user: $TARGET_USER"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_UID="$(id -u "$TARGET_USER")"

# A user scope for another account needs admin rights; the caller is not root
# (lui refuses root), so escalate with sudo -u for exactly those commands.
if [[ "$TARGET_USER" != "$CURRENT_USER" ]]; then
  require_admin_for_target=true
else
  require_admin_for_target=false
fi

as_target() {
  local u="$1"; shift
  if [[ "$u" == "$CURRENT_USER" ]]; then
    "$@"
  else
    local envs=(HOME="$TARGET_HOME" USER="$u" LOGNAME="$u")
    [[ -d "/run/user/$TARGET_UID" ]] && envs+=(XDG_RUNTIME_DIR="/run/user/$TARGET_UID")
    sudo -u "$u" env "${envs[@]}" "$@"
  fi
}

require_system_admin() {
  # Prompt once if there is no cached ticket; fail clearly if the account is
  # not allowed (the work account is intentionally non-admin). Never hide the
  # prompt: sudo writes it to stderr.
  if ! sudo -n true 2>/dev/null; then
    sudo -v || die "--system needs an admin account (run as luci)"
  fi
}

# Scope defaults: a dry-run/status previews everything (read-only, no sudo);
# a real add only claims system scope when admin rights are demonstrably there.
HINT_SYSTEM=false
if [[ -z "$SCOPE" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    SCOPE=both
  elif sudo -n true 2>/dev/null; then
    SCOPE=both
  else
    SCOPE=user
    HINT_SYSTEM=true
  fi
fi

case "$SCOPE" in
  system) DO_SYSTEM=true;  DO_USER=false ;;
  user)   DO_SYSTEM=false; DO_USER=true ;;
  both)   DO_SYSTEM=true;  DO_USER=true ;;
esac

echo "=== lui sync (v0.1, manual-only) ==="
echo "scope: $SCOPE$([[ "$DO_USER" == true ]] && echo " (user: $TARGET_USER)")"
if [[ "$DRY_RUN" == true ]]; then echo "(dry-run: no changes will be made)"; fi

# --- ADD path ---------------------------------------------------------------
if [[ "$DRY_RUN" == false ]]; then
  if [[ "$DO_SYSTEM" == true ]]; then
    require_system_admin
  fi
  if [[ "$require_admin_for_target" == true && "$DO_USER" == true ]]; then
    # sudo -u below will prompt; verify the target exists (done) and that we can
    # actually escalate before doing half the work.
    sudo -n true 2>/dev/null || sudo -v \
      || die "--user $TARGET_USER needs an admin account (run as luci)"
  fi
fi

if [[ "$DRY_RUN" == false ]]; then
  if [[ "$DO_SYSTEM" == true ]]; then
    "$ROOT/scripts/ensure-packages.sh"
    "$ROOT/scripts/ensure-flatpaks.sh" --system
    echo "==> flatpak update + cleanup (system)"
    flatpak update -y --system || true
    flatpak uninstall --unused -y --system || true
  fi
  if [[ "$DO_USER" == true ]]; then
    as_target "$TARGET_USER" "$ROOT/scripts/ensure-flatpaks.sh" --user
    as_target "$TARGET_USER" "$ROOT/scripts/generate-local-apps.sh"
    echo "==> flatpak update + cleanup (user: $TARGET_USER)"
    as_target "$TARGET_USER" flatpak update -y --user || true
    as_target "$TARGET_USER" flatpak uninstall --unused -y --user || true
  fi
else
  [[ "$DO_SYSTEM" == true ]] && echo "[dry-run] would run ensure-packages.sh + ensure-flatpaks.sh --system"
  [[ "$DO_USER" == true ]] && echo "[dry-run] would run ensure-flatpaks.sh --user + generate-local-apps.sh for $TARGET_USER"
fi

if [[ "$HINT_SYSTEM" == true ]]; then
  cat <<'EOF'

NOTE: system scope was skipped (this account has no admin rights).
      Run as the admin account (luci):   lui sync --system
      Then re-run the user half here:    lui sync --user
EOF
fi

# --- PRUNE path (opt-in only) ----------------------------------------------
if [[ "$PRUNE" == false ]]; then
  echo "=== done (add-only). Re-run with --prune to remove extras not in lists. ==="
  exit 0
fi

echo "=== prune preview (extras NOT in lists, scope: $SCOPE) ==="
PACMAN_EXTRAS=(); FP_SYS_EXTRAS=(); FP_USR_EXTRAS=()

if [[ "$DO_SYSTEM" == true ]]; then
  # pacman extras = explicitly installed - (desired pacman/AUR + protected)
  mapfile -t DESIRED < <(cat "$ROOT/config/packages" "$ROOT/config/packages-arch" 2>/dev/null | grep -vE '^\s*#' | grep -vE '^\s*$' | sort -u || true)
  mapfile -t PROTECTED < <(cat "$ROOT/config/protected-packages" 2>/dev/null | grep -vE '^\s*#' | grep -vE '^\s*$' | sort -u || true)
  mapfile -t EXPLICIT < <(pacman -Qqe | sort -u || true)
  declare -A KEEP=()
  for p in "${DESIRED[@]}" "${PROTECTED[@]}"; do KEEP["$p"]=1; done
  for p in "${EXPLICIT[@]}"; do [[ -z "${KEEP[$p]:-}" ]] && PACMAN_EXTRAS+=("$p"); done
  echo "pacman extras (${#PACMAN_EXTRAS[@]}): ${PACMAN_EXTRAS[*]:-(none)}"

  # system flatpak extras (legacy flatpaks.list is system scope)
  mapfile -t DESIRED_FP_SYS < <(cat "$ROOT/config/flatpaks-system.list" "$ROOT/config/flatpaks.list" 2>/dev/null \
    | grep -vE '^\s*#' | grep -vE '^\s*$' | awk '{print $2}' | sort -u || true)
  mapfile -t INSTALLED_SYS < <(flatpak list --system --app --columns=application 2>/dev/null | sort -u || true)
  declare -A KEEP_FP_SYS=()
  for a in "${DESIRED_FP_SYS[@]}"; do KEEP_FP_SYS["$a"]=1; done
  for a in "${INSTALLED_SYS[@]}"; do [[ -z "${KEEP_FP_SYS[$a]:-}" ]] && FP_SYS_EXTRAS+=("$a"); done
  echo "flatpak system extras (${#FP_SYS_EXTRAS[@]}): ${FP_SYS_EXTRAS[*]:-(none)}"
fi

if [[ "$DO_USER" == true ]]; then
  mapfile -t DESIRED_FP_USR < <(cat "$ROOT/config/flatpaks-user.list" 2>/dev/null \
    | grep -vE '^\s*#' | grep -vE '^\s*$' | awk '{print $2}' | sort -u || true)
  mapfile -t INSTALLED_USR < <(as_target "$TARGET_USER" flatpak list --user --app --columns=application 2>/dev/null | sort -u || true)
  declare -A KEEP_FP_USR=()
  for a in "${DESIRED_FP_USR[@]}"; do KEEP_FP_USR["$a"]=1; done
  for a in "${INSTALLED_USR[@]}"; do [[ -z "${KEEP_FP_USR[$a]:-}" ]] && FP_USR_EXTRAS+=("$a"); done
  echo "flatpak user extras (${#FP_USR_EXTRAS[@]}, $TARGET_USER): ${FP_USR_EXTRAS[*]:-(none)}"
fi

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
  echo "==> removing flatpak user extras ($TARGET_USER)"
  as_target "$TARGET_USER" flatpak uninstall -y --user "${FP_USR_EXTRAS[@]}"
fi
echo "=== sync --prune complete ==="