#!/usr/bin/env bash
# scripts/theme.sh — LuicipherOS theme control ("lui theme").
#
# Preset palettes live in themes/<name>.json in the repo tree (shared base,
# contributed via the repo). Applying a preset writes the palette keys into the
# per-user Quickshell override (~/.config/lui/quickshell/tokens.json) — the
# shell hot-reloads them; nothing in the shared base is touched.
#
# USAGE
#   lui theme list                    available presets
#   lui theme show                    current user tokens + active preset guess
#   lui theme set <preset>            apply a preset
#   lui theme set wallpaper <image>   generate palette from a wallpaper (matugen)
#   lui theme reset                   drop palette keys -> back to shared base
set -euo pipefail

# Own tree = parent of this script. When run via `lui theme` lui.sh already
# resolved the canonical tree; theme files live beside the scripts regardless.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEMES_DIR="$ROOT/themes"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
TOKENS="$CFG/lui/quickshell/tokens.json"

die() { printf 'lui theme: %s\n' "$*" >&2; exit 1; }
require_jq() { command -v jq >/dev/null || die "jq is required (lui sync will install it)"; }

PALETTE_KEYS=(bg surface fg muted accent alt warn fontFamily)

list() {
  echo "presets ($THEMES_DIR):"
  for f in "$THEMES_DIR"/*.json; do
    [[ -e $f ]] || { echo "  (none)"; return; }
    printf '  %-14s %s\n' "$(basename "$f" .json)" "$(jq -r .name "$f")"
  done
}

current() {
  [[ -f $TOKENS ]] || { echo "no user override yet - using the shared base"; return; }
  echo "user tokens: $TOKENS"
  jq '{barHeight, accent, bg, fg}' "$TOKENS" 2>/dev/null || cat "$TOKENS"
  local base match
  for f in "$THEMES_DIR"/*.json; do
    [[ -e $f ]] || continue
    match=1
    for k in "${PALETTE_KEYS[@]}"; do
      base=$(jq -r ".${k} // empty" "$f")
      [[ -z $base ]] && continue
      [[ "$(jq -r ".${k} // empty" "$TOKENS")" == "$base" ]] || { match=0; break; }
    done
    (( match )) && { echo "matches preset: $(basename "$f" .json)"; return; }
  done
  echo "(no exact preset match - custom/wallpaper palette)"
}

apply_json() { # $1 = json file with palette keys
  require_jq
  [[ -f $1 ]] || die "no such theme file: $1"
  mkdir -p "$(dirname "$TOKENS")"
  local cur='{}'
  [[ -f $TOKENS ]] && cur=$(cat "$TOKENS")
  jq -s '.[0] + (.[1] | del(.name))' <(echo "$cur") "$1" > "$TOKENS.tmp"
  # validate before replacing
  jq -e . "$TOKENS.tmp" >/dev/null || die "resulting tokens invalid, aborted"
  mv "$TOKENS.tmp" "$TOKENS"
  echo "applied -> $TOKENS  (Quickshell hot-reloads within ~2 s)"
}

set_theme() {
  local what="${1:-}"
  [[ -n $what ]] || die "usage: lui theme set <preset|wallpaper <image>>"
  if [[ $what == wallpaper ]]; then
    local img="${2:-}"
    [[ -n $img && -f $img ]] || die "usage: lui theme set wallpaper <image-file>"
    command -v matugen >/dev/null || die "matugen not installed (add to config/packages -> lui sync)"
    require_jq
    # NOTE: flag/subcommand form verified against `matugen --help` at install
    # time (matugen 4.x: `matugen -p json -t material image <file>`).
    local out
    out=$(matugen -p json -t material image "$img" 2>/dev/null) \
      || die "matugen failed on $img"
    mkdir -p "$(dirname "$TOKENS")"
    # Map Material You tones onto the lui token names (dark scheme, defensive
    # fallbacks in case a tone key differs across matugen versions).
    printf '%s' "$out" | jq '{
      bg:      (.neutral6.hex // .neutral4.hex),
      surface: (.neutral12.hex // .neutral6.hex),
      fg:      .neutral90.hex,
      muted:   (.neutral40.hex // .neutral50.hex),
      accent:  (.primary80.hex // .primary40.hex),
      alt:     (.secondary80.hex // .secondary40.hex),
      warn:    (.tertiary80.hex // .tertiary40.hex)
    }' > "$TOKENS.generated"
    apply_json "$TOKENS.generated"
    rm -f "$TOKENS.generated"
    printf '%s' "$out" > "$(dirname "$TOKENS")/palette.json"   # raw palette for other apps
    echo "raw palette kept at $(dirname "$TOKENS")/palette.json"
    return
  fi
  apply_json "$THEMES_DIR/$what.json"
}

reset() {
  [[ -f $TOKENS ]] || { echo "nothing to reset"; return; }
  require_jq
  jq 'del(.bg, .surface, .fg, .muted, .accent, .alt, .warn, .fontFamily)' \
    "$TOKENS" > "$TOKENS.tmp" && mv "$TOKENS.tmp" "$TOKENS"
  echo "palette keys removed - user is back on the shared base"
}

cmd="${1:-list}"; shift || true
case "$cmd" in
  list)    list ;;
  show)    current ;;
  set)     set_theme "$@" ;;
  reset)   reset ;;
  *)       die "unknown subcommand: $cmd (list|show|set|reset)" ;;
esac
