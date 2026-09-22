#!/usr/bin/env bash
# tests/test_sync.sh — contract tests for scripts/sync.sh ("luci sync").
# Seams (CLI behavior, pre-agreed per issue #1 step 2):
#   1. add-only default: installs missing, never removes
#   2. --prune --dry-run: previews extras, changes nothing
#   3. protected-packages guard: protected base never listed as extras
#   4. system/user flatpak split: extras attributed per scope
# Method: mock pacman/flatpak/sudo earlier on PATH + fixture config dir.
# USAGE: ./tests/test_sync.sh   (exit 0 = all pass)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAILN=0
ok()   { PASS=$((PASS+1)); echo "  ok: $1"; }
bad()  { FAILN=$((FAILN+1)); echo "  FAIL: $1"; }

# --- fixture sandbox ---
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/cfg" "$T/calls"
cat > "$T/cfg/packages" <<'EOF'
# desired pacman
kitty
waybar
EOF
cat > "$T/cfg/packages-arch" <<'EOF'
vicinae
EOF
cat > "$T/cfg/protected-packages" <<'EOF'
linux
hyprland
EOF
cat > "$T/cfg/flatpaks-system.list" <<'EOF'
flathub org.mozilla.firefox stable
EOF
cat > "$T/cfg/flatpaks-user.list" <<'EOF'
flathub md.obsidian.Obsidian stable
EOF
touch "$T/cfg/flatpaks.list"

# --- mocks ---
# pacman -Qqe: desired kitty + protected linux/hyprland + extras extra-pkg, orphan-aur
cat > "$T/bin/pacman" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-Qqe" ]]; then
  printf '%s\n' hyprland kitty linux extra-pkg orphan-aur waybar
else
  echo "pacman $*" >> "$CALLS_DIR/pacman-calls"
fi
EOF
# flatpak list/info/uninstall/update: canned per scope, record mutations
cat > "$T/bin/flatpak" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "list" ]]; then
  if [[ "$*" == *"--system"* ]]; then
    printf '%s\n' org.mozilla.firefox com.example.SysExtra
  elif [[ "$*" == *"--user"* ]]; then
    printf '%s\n' md.obsidian.Obsidian com.example.UserExtra
  fi
elif [[ "$1" == "uninstall" ]]; then
  # routine `uninstall --unused` cleanup is allowed in add-only mode;
  # only record app-ID removals (extra pruning)
  [[ "$*" == *"--unused"* ]] || echo "flatpak $*" >> "$CALLS_DIR/flatpak-calls"
else
  : # info/update: silent success
fi
EOF
cat > "$T/bin/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >> "$CALLS_DIR/sudo-calls"
EOF
chmod +x "$T/bin/"*
export PATH="$T/bin:$PATH"
export CALLS_DIR="$T/calls"

# Point sync.sh at fixture config without touching the repo:
# sync.sh derives ROOT from its own path, so shadow config via a temp
# repo-layout symlink tree instead.
M="$T/repo"
mkdir -p "$M/config" "$M/scripts"
cp "$T/cfg/"* "$M/config/"
cp "$ROOT/scripts/sync.sh" "$M/scripts/"
# stub ensure scripts (add path must run but do nothing here)
printf '#!/usr/bin/env bash\necho "ensure-packages stub"\n' > "$M/scripts/ensure-packages.sh"
printf '#!/usr/bin/env bash\necho "ensure-flatpaks stub"\n' > "$M/scripts/ensure-flatpaks.sh"
chmod +x "$M/scripts/"*.sh
SYNC="$M/scripts/sync.sh"

echo "== 1. add-only default installs, never removes =="
OUT=$(bash "$SYNC" 2>&1)
[[ "$OUT" == *"add-only"* ]] && ok "add-only banner, exits 0" || bad "missing add-only banner: $OUT"
[[ ! -f "$T/calls/sudo-calls" && ! -f "$T/calls/flatpak-calls" ]] \
  && ok "no removals in add-only mode" \
  || bad "removal attempted in add-only mode"

echo "== 2. --prune --dry-run previews extras, changes nothing =="
rm -f "$T/calls"/{sudo-calls,flatpak-calls,pacman-calls}
OUT=$(bash "$SYNC" --prune --dry-run 2>&1)
[[ "$OUT" == *"extra-pkg"* && "$OUT" == *"orphan-aur"* ]] \
  && ok "pacman extras previewed" || bad "pacman extras missing: $OUT"
[[ "$OUT" == *"com.example.SysExtra"* ]] \
  && ok "system flatpak extra previewed" || bad "system extra missing: $OUT"
[[ "$OUT" == *"com.example.UserExtra"* ]] \
  && ok "user flatpak extra previewed" || bad "user extra missing: $OUT"
[[ "$OUT" == *"dry-run, stopping before removal"* ]] \
  && ok "dry-run stops before removal" || bad "no dry-run stop: $OUT"
[[ ! -f "$T/calls/sudo-calls" && ! -f "$T/calls/flatpak-calls" ]] \
  && ok "dry-run changed nothing" || bad "dry-run mutated system"

echo "== 3. protected-packages guard =="
[[ "$OUT" != *"pacman extras"*linux* && "$OUT" == *"extra-pkg"* ]] && ok "protected linux/hyprland excluded from extras" \
  || bad "protected package leaked into extras: $OUT"
# negative check done precisely:
if echo "$OUT" | grep -E "^pacman extras" | grep -qw "linux"; then
  bad "linux listed as pacman extra"
else
  ok "linux NOT listed as pacman extra"
fi
if echo "$OUT" | grep -E "^pacman extras" | grep -qw "hyprland"; then
  bad "hyprland listed as pacman extra"
else
  ok "hyprland NOT listed as pacman extra"
fi

echo "== 4. system/user flatpak split =="
SYS_LINE=$(echo "$OUT" | grep -E "^flatpak system extras")
USR_LINE=$(echo "$OUT" | grep -E "^flatpak user extras")
[[ "$SYS_LINE" == *"SysExtra"* && "$SYS_LINE" != *"UserExtra"* ]] \
  && ok "system extras attributed to system scope" || bad "system scope wrong: $SYS_LINE"
[[ "$USR_LINE" == *"UserExtra"* && "$USR_LINE" != *"SysExtra"* ]] \
  && ok "user extras attributed to user scope" || bad "user scope wrong: $USR_LINE"

echo "== 5. --prune --yes removes extras via correct commands =="
rm -f "$T/calls"/{sudo-calls,flatpak-calls,pacman-calls}
OUT=$(bash "$SYNC" --prune --yes 2>&1)
[[ -f "$T/calls/sudo-calls" ]] && SUDO_CALLS=$(cat "$T/calls/sudo-calls") || SUDO_CALLS=""
[[ -f "$T/calls/flatpak-calls" ]] && FP_CALLS=$(cat "$T/calls/flatpak-calls") || FP_CALLS=""
[[ "$SUDO_CALLS" == *"pacman -Rns"* && "$SUDO_CALLS" == *"extra-pkg"* ]] \
  && ok "pacman extras removed via sudo pacman -Rns" || bad "pacman removal wrong: $SUDO_CALLS"
[[ "$SUDO_CALLS" != *"linux"* && "$SUDO_CALLS" != *"hyprland"* ]] \
  && ok "protected packages never passed to pacman -Rns" || bad "protected in removal: $SUDO_CALLS"
[[ "$FP_CALLS" == *"--system"*SysExtra* ]] \
  && ok "system extra uninstalled with --system" || bad "system uninstall wrong: $FP_CALLS"
[[ "$FP_CALLS" == *"--user"*UserExtra* ]] \
  && ok "user extra uninstalled with --user" || bad "user uninstall wrong: $FP_CALLS"

echo "== 6. no extras -> nothing to prune =="
cat > "$T/bin/pacman" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-Qqe" ]]; then
  printf '%s\n' hyprland kitty linux waybar vicinae
else
  echo "pacman $*" >> "$CALLS_DIR/pacman-calls"
fi
EOF
cat > "$T/bin/flatpak" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "list" ]]; then
  if [[ "$*" == *"--system"* ]]; then
    printf '%s\n' org.mozilla.firefox
  elif [[ "$*" == *"--user"* ]]; then
    printf '%s\n' md.obsidian.Obsidian
  fi
elif [[ "$1" == "uninstall" ]]; then
  [[ "$*" == *"--unused"* ]] || echo "flatpak $*" >> "$CALLS_DIR/flatpak-calls"
else
  :
fi
EOF
chmod +x "$T/bin/"*
rm -f "$T/calls"/{sudo-calls,flatpak-calls,pacman-calls}
OUT=$(bash "$SYNC" --prune --dry-run 2>&1)
[[ "$OUT" == *"nothing to prune"* ]] \
  && ok "nothing-to-prune short-circuits" || bad "missing nothing-to-prune: $OUT"

echo ""
echo "tests: $PASS passed, $FAILN failed"
[[ "$FAILN" -eq 0 ]]
