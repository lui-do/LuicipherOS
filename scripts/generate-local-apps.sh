#!/usr/bin/env bash
# scripts/generate-local-apps.sh — expose ~/.local/bin tools in a desktop launcher.
#
# Vicinae (and any XDG launcher) reads .desktop files, not $PATH, so tools that
# exist only in ~/.local/bin are invisible to it. This generator turns the
# declarative list `config/local-apps` into managed .desktop files in the user
# XDG applications dir.
#
# Properties:
#   - Idempotent: re-running overwrites only the files it generated.
#   - Safe: generated files are named `luci-local-<name>.desktop` and carry
#     `X-LuicipherOS=generated`, so it never touches user-authored entries.
#   - `--remove` deletes exactly the managed files and nothing else.
#
# USAGE:
#   scripts/generate-local-apps.sh            # (re)generate
#   scripts/generate-local-apps.sh --remove   # remove the managed entries
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIST="$ROOT/config/local-apps"
BIN_DIR="$HOME/.local/bin"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
PREFIX="luci-local-"

[[ -f "$LIST" ]] || { echo "generate-local-apps: no $LIST" >&2; exit 1; }
mkdir -p "$DEST"

if [[ "${1:-}" == "--remove" ]]; then
  n=0
  for f in "$DEST/${PREFIX}"*.desktop; do
    [[ -e "$f" ]] || continue
  rm -f "$f"; echo "removed $f"; n=$((n+1))
  done
  echo "done: removed $n managed local-app entr$( [[ $n -eq 1 ]] && y || ies )"
  exit 0
fi

count=0
while IFS= read -r line || [[ -n "$line" ]]; do
  # strip a trailing carriage return (in case of CRLF) and skip comments/blanks
  line="${line%$'\r'}"
  [[ -z "${line//[[:space:]]/}" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue

  # first whitespace-delimited token = basename; the rest = optional display name
  name="${line%%[[:space:]]*}"
  rest="${line#"$name"}"
  rest="${rest#"${rest%%[![:space:]]*}"}"   # ltrim
  [[ -n "$rest" ]] && display="$rest" || display="$name"

  exe="$BIN_DIR/$name"
  if [[ ! -x "$exe" ]]; then
    echo "  WARN: $exe not found or not executable — skipping $name" >&2
    continue
  fi

  out="$DEST/${PREFIX}${name}.desktop"
  cat > "$out" <<EOF
[Desktop Entry]
Type=Application
Name=$display
Exec=$exe
Terminal=true
Icon=utilities-terminal
Comment=Local tool in ~/.local/bin (managed by LuicipherOS)
X-LuicipherOS=generated
X-luicipheros-source=$BIN_DIR
EOF
  echo "  wrote $out  (\"$display\" -> $exe)"
  count=$((count+1))
done < "$LIST"

echo "done: $count local app(s) exposed in $DEST"
echo "If the launcher does not show them, restart it (Vicinae: re-launch, or"
echo "'systemctl --user restart vicinae' if it runs as a service)."
echo "Re-run this script any time you add a tool to ~/.local/bin + config/local-apps."
