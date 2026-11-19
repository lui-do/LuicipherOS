#!/usr/bin/env bash
# scripts/ai.sh — `lui ai` (ADR-0002): local-first, system-wide AI stack.
#
# Admin (luci):  sync (download weights), enable/disable, disable --prune
# Any account:   status, run, bench, audit, cloud
#
# Weights are data, not packages: config/models.json is the manifest, and
# /var/lib/llm/models holds the verified files referenced by llama-swap.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${LUI_AI_MANIFEST:-$ROOT/config/models.json}"
STORE="${LUI_AI_STORE:-/var/lib/llm/models}"
ENDPOINT="${LUI_AI_ENDPOINT:-http://127.0.0.1:12434}"
DISABLED_FLAG="${LUI_AI_DISABLED_FLAG:-/etc/lui/ai.disabled}"
AI_PACKAGES_FILE="$ROOT/config/ai-packages"
USER_ENV="${XDG_CONFIG_HOME:-$HOME/.config}/lui/ai.env"
GOOSE_BIN="${LUI_GOOSE_BIN:-goose}"

die() { printf 'lui ai: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
usage: lui ai <command>

  status                 service, endpoint, model files and aliases (read-only)
  sync [--dry-run] [--yes] [--verify] [MODEL...]
                         download/verify weights into /var/lib/llm/models (admin)
  run [MODEL] [ARGS...]  start Goose against the local endpoint (default: general)
  bench [MODEL...]       one-shot latency/token check per model
  audit                  local-only / telemetry / key checks
  cloud <PROVIDER> [MODEL] [ARGS...]
                         explicit hosted session using this user's key (no fallback)
  enable                 remove the disabled flag, enable llama-swap (admin)
  disable                stop the endpoint; keep packages and models (admin)
  disable --prune        stop and remove AI packages, models and service files (admin)

Models: general, coding, coding-hq (alias of general), research.
EOF
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

require_admin() {
  if sudo -n true 2>/dev/null; then return 0; fi
  sudo -v || die "this command needs the admin account (luci)"
}

size_human() { # bytes
  numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || printf '%s B' "$1"
}

manifest_rows() { # optional model/alias filter
  python3 - "$MANIFEST" "$@" <<'PY'
import json, sys
path, sel = sys.argv[1], set(sys.argv[2:])
d = json.load(open(path))
for m in d["models"]:
    names = {m["id"], *m.get("aliases", [])}
    if sel and not (names & sel):
        continue
    print("\x1f".join([
        m["id"], ",".join(m.get("aliases", [])), m["file"], m["repo"],
        m["source_file"], str(m["size_bytes"]), m["sha256"],
        str(m.get("context", 0)), m.get("license", ""), m.get("role", ""),
    ]))
PY
}

model_ids() {
  python3 - "$MANIFEST" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for m in d["models"]:
    print(m["id"])
    for a in m.get("aliases", []):
        print(a)
PY
}

resolve_id() { # alias -> canonical id; fails if unknown
  python3 - "$MANIFEST" "$1" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for m in d["models"]:
    if m["id"] == sys.argv[2] or sys.argv[2] in m.get("aliases", []):
        print(m["id"]); sys.exit(0)
sys.exit(1)
PY
}

endpoint_up() { curl -fsS -m 3 "$ENDPOINT/v1/models" >/dev/null 2>&1; }

cmd_status() {
  local active enabled
  active="$(systemctl is-active llama-swap 2>/dev/null || true)"
  enabled="$(systemctl is-enabled llama-swap 2>/dev/null || true)"
  echo "== lui ai =="
  echo "service:  ${active:-unknown} (${enabled:-unknown})"
  echo "endpoint: $ENDPOINT"
  if [[ -e "$DISABLED_FLAG" ]]; then
    echo "switch:   DISABLED (lui ai enable to restore)"
  else
    echo "switch:   enabled"
  fi
  if findmnt -M "$( [[ "$STORE" == "/var/lib/llm/models" ]] && echo /var/lib/llm || dirname "$STORE" )" >/dev/null 2>&1; then
    echo "store:    /var/lib/llm mounted"
  else
    echo "store:    WARN /var/lib/llm is not a mount point"
  fi
  echo "models:"
  while IFS=$'\x1f' read -r id aliases file repo src size sha ctx lic role; do
    [[ -z "$id" ]] && continue
    local path="$STORE/$file" state="missing"
    if [[ -f "$path" ]]; then
      local actual; actual="$(stat -c %s "$path" 2>/dev/null || echo 0)"
      if [[ "$actual" == "$size" ]]; then state="ok"; else state="size-mismatch"; fi
    fi
    printf '  %-9s %-11s %-13s %s\n' "$id" "$file" "$state" "$(size_human "$size")"
  done < <(manifest_rows)
  echo "aliases:  $(model_ids | tr '\n' ' ')"
  if endpoint_up; then
    echo "upstream: reachable"
  else
    echo "upstream: NOT reachable (sudo systemctl start llama-swap)"
  fi
}

cmd_sync() {
  local dry=false yes=false verify=false
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry=true ;;
      --yes|-y) yes=true ;;
      --verify) verify=true ;;
      -h|--help) usage; return 0 ;;
      -*) die "unknown sync flag: $1" ;;
      *) args+=("$1") ;;
    esac
    shift
  done

  local rows=() missing=0 total_bytes=0
  while IFS=$'\x1f' read -r id aliases file repo src size sha ctx lic role; do
    [[ -z "$id" ]] && continue
    local path="$STORE/$file"
    if [[ -f "$path" ]]; then
      local actual; actual="$(stat -c %s "$path" 2>/dev/null || echo 0)"
      if [[ "$actual" == "$size" ]]; then
        if [[ "$verify" == true ]]; then
          echo "==> verifying $id ($file)"
          local got; got="$(sha256sum "$path" | awk '{print $1}')"
          [[ "$got" == "$sha" ]] || die "checksum mismatch: $path (remove it and re-run)"
          echo "    ok"
        else
          echo "==> $id: present ($(size_human "$size"))"
        fi
        continue
      fi
      echo "==> $id: size mismatch, will re-download"
    fi
    rows+=("$id|$file|$repo|$src|$size|$sha")
    total_bytes=$((total_bytes + size))
    missing=$((missing + 1))
  done < <(manifest_rows "${args[@]}")

  if [[ "$missing" -eq 0 ]]; then
    echo "==> all selected models present"
    return 0
  fi

  echo "==> $missing model(s) to download, $(size_human "$total_bytes") total"
  if [[ "$dry" == true ]]; then
    local row; for row in "${rows[@]}"; do
      IFS='|' read -r id file repo src size sha <<<"$row"
      echo "    $id -> $STORE/$file"
      echo "      https://huggingface.co/$repo/resolve/main/$src"
    done
    echo "==> dry-run, nothing downloaded"
    return 0
  fi

  require_cmd curl; require_cmd sha256sum
  require_admin
  if [[ "$yes" != true ]]; then
    local ans
    read -r -p "Download $(size_human "$total_bytes") into $STORE? [y/N] " ans
    [[ "$ans" == "y" || "$ans" == "Y" ]] || die "aborted"
  fi
  sudo install -d -m755 "$STORE"

  local row; for row in "${rows[@]}"; do
    IFS='|' read -r id file repo src size sha <<<"$row"
    local url="https://huggingface.co/$repo/resolve/main/$src?download=true"
    local dest="$STORE/$file"
    echo "==> downloading $id -> $dest"
    sudo curl -fL --retry 3 --continue-at - -o "$dest.part" "$url"
    local got; got="$(sudo sha256sum "$dest.part" | awk '{print $1}')"
    if [[ -n "$sha" && "$got" != "$sha" ]]; then
      sudo rm -f "$dest.part"
      die "checksum mismatch for $id (expected $sha, got $got)"
    fi
    sudo mv "$dest.part" "$dest"
    sudo chmod 644 "$dest"
    echo "    ok ($(size_human "$size"))"
  done
  echo "==> models ready; llama-swap will load them on first request"
}

cmd_run() {
  local alias="general"
  if [[ $# -gt 0 && "$1" != -* ]]; then
    resolve_id "$1" >/dev/null || die "unknown model: $1 (try: $(model_ids | tr '\n' ' '))"
    alias="$1"; shift
  fi
  resolve_id "$alias" >/dev/null || die "unknown model: $alias"
  endpoint_up || die "llama-swap is not reachable at $ENDPOINT (start: sudo systemctl start llama-swap)"
  if [[ -f "$USER_ENV" ]]; then set -a; . "$USER_ENV"; set +a; fi
  export GOOSE_PROVIDER=openai
  export GOOSE_PROVIDER__HOST="$ENDPOINT"
  export GOOSE_PROVIDER__API_KEY="${GOOSE_PROVIDER__API_KEY:-local}"
  export GOOSE_MODEL="$alias"
  export GOOSE_TELEMETRY_ENABLED=false
  export OTEL_SDK_DISABLED=true
  command -v "$GOOSE_BIN" >/dev/null 2>&1 && exec "$GOOSE_BIN" "$@"
  if [[ "$GOOSE_BIN" == */* && -x "$GOOSE_BIN" ]]; then exec "$GOOSE_BIN" "$@"; fi
  die "goose not installed (step 4: goose-desktop-bin); set LUI_GOOSE_BIN to test"
}

cmd_cloud() {
  local provider="${1:-}"
  [[ -n "$provider" ]] || die "usage: lui ai cloud <provider> [MODEL] [ARGS...]"
  shift
  local model=""
  if [[ $# -gt 0 && "$1" != -* ]]; then model="$1"; shift; fi
  [[ -f "$USER_ENV" ]] || die "no $USER_ENV (add your own provider key, mode 0600)"
  set -a; . "$USER_ENV"; set +a
  local key=""
  case "$provider" in
    openrouter) key="${OPENROUTER_API_KEY:-}" ;;
    anthropic) key="${ANTHROPIC_API_KEY:-}" ;;
    openai) key="${OPENAI_API_KEY:-}" ;;
    google|gemini) key="${GEMINI_API_KEY:-}" ;;
  esac
  export GOOSE_PROVIDER__API_KEY="${GOOSE_PROVIDER__API_KEY:-$key}"
  [[ -n "${GOOSE_PROVIDER__API_KEY:-}" ]] \
    || die "set GOOSE_PROVIDER__API_KEY (or the provider's *_API_KEY) in $USER_ENV; keys are per-user, never system-wide"
  export GOOSE_PROVIDER="$provider"
  [[ -n "$model" ]] && export GOOSE_MODEL="$model"
  export GOOSE_TELEMETRY_ENABLED=false OTEL_SDK_DISABLED=true
  command -v "$GOOSE_BIN" >/dev/null 2>&1 || die "goose not installed"
  exec "$GOOSE_BIN" "$@"
}

cmd_audit() {
  local problems=0
  echo "== lui ai audit =="
  case "$ENDPOINT" in
    http://127.0.0.1:*|http://localhost:*) echo "PASS  endpoint is loopback ($ENDPOINT)" ;;
    *) echo "FAIL  endpoint is not loopback: $ENDPOINT"; problems=$((problems+1)) ;;
  esac
  if endpoint_up; then echo "PASS  llama-swap reachable"; else echo "WARN  llama-swap not reachable"; fi
  if grep -qs 'GOOSE_TELEMETRY_ENABLED=false' /etc/environment.d/* 2>/dev/null; then
    echo "PASS  Goose telemetry pinned off in /etc/environment.d"
  else
    echo "WARN  Goose telemetry pin not found in /etc/environment.d (step 4)"
  fi
  if grep -RqsE 'API_KEY=|_API_KEY=' /etc/environment.d /etc/lui 2>/dev/null; then
    echo "FAIL  API key material found under /etc (must be user-only)"; problems=$((problems+1))
  else
    echo "PASS  no API keys under /etc/environment.d or /etc/lui"
  fi
  if [[ -f "$USER_ENV" ]]; then
    local mode; mode="$(stat -c %a "$USER_ENV")"
    if [[ "$mode" == "600" ]]; then echo "PASS  $USER_ENV is 0600"; else
      echo "FAIL  $USER_ENV is $mode (should be 600)"; problems=$((problems+1)); fi
  else
    echo "INFO  no per-user cloud keys ($USER_ENV absent)"
  fi
  if [[ -f "$HOME/.config/opencode/opencode.json" ]]; then
    grep -qs '"share": *"disabled"' "$HOME/.config/opencode/opencode.json" \
      && echo "PASS  OpenCode share disabled" || echo "WARN  OpenCode share not pinned disabled"
    grep -qs '"openTelemetry": *false' "$HOME/.config/opencode/opencode.json" \
      && echo "PASS  OpenCode telemetry disabled" || echo "WARN  OpenCode telemetry not pinned off"
  else
    echo "INFO  OpenCode config not found yet"
  fi
  if [[ -f "$HOME/.pi/agent/settings.json" ]]; then
    grep -qs '"enableInstallTelemetry": *false' "$HOME/.pi/agent/settings.json" \
      && echo "PASS  Pi install telemetry disabled" || echo "WARN  Pi install telemetry not pinned off"
    grep -qs '"enableAnalytics": *false' "$HOME/.pi/agent/settings.json" \
      && echo "PASS  Pi analytics disabled" || echo "WARN  Pi analytics not pinned off"
  else
    echo "INFO  Pi settings not found yet"
  fi
  echo "INFO  Pi telemetry env: PI_TELEMETRY=${PI_TELEMETRY:-unset} (must be 0)"
  [[ "$problems" -eq 0 ]] && echo "== audit complete: no critical issues ==" \
    || { echo "== audit complete: $problems critical issue(s) =="; return 1; }
}

cmd_bench() {
  local args=("$@")
  local found=0
  while IFS=$'\x1f' read -r id aliases file repo src size sha ctx lic role; do
    [[ -z "$id" ]] && continue
    found=1
    echo "==> $id (ctx $ctx)"
    python3 - "$ENDPOINT" "$id" <<'PY'
import json, sys, time, urllib.request
endpoint, model = sys.argv[1], sys.argv[2]
body = json.dumps({"model": model, "messages": [{"role": "user", "content": "Reply with OK."}],
                   "max_tokens": 16, "stream": False}).encode()
req = urllib.request.Request(endpoint + "/v1/chat/completions", data=body,
                             headers={"Content-Type": "application/json"})
t0 = time.monotonic()
try:
    with urllib.request.urlopen(req, timeout=900) as r:
        out = json.load(r)
except Exception as e:
    print(f"    FAIL: {e}"); sys.exit(1)
elapsed = time.monotonic() - t0
usage = out.get("usage", {})
n = usage.get("completion_tokens") or 0
print(f"    {elapsed:.2f}s total (load + {n} tokens)" + (f", {n/elapsed:.1f} tok/s" if n and elapsed else ""))
PY
  done < <(manifest_rows "${args[@]}")
  [[ "$found" -eq 1 ]] || die "no models selected"
}

cmd_enable() {
  require_admin
  sudo install -d -m755 /etc/lui
  sudo rm -f "$DISABLED_FLAG"
  sudo systemctl enable --now llama-swap
  echo "==> AI stack enabled; endpoint $ENDPOINT"
}

cmd_disable() {
  local prune=false yes=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prune) prune=true ;;
      --yes|-y) yes=true ;;
      -h|--help) usage; return 0 ;;
      *) die "unknown disable flag: $1" ;;
    esac
    shift
  done
  require_admin
  sudo install -d -m755 /etc/lui
  sudo touch "$DISABLED_FLAG"
  sudo systemctl disable --now llama-swap 2>/dev/null || true
  echo "==> AI stack disabled: endpoint stopped; packages and models kept"
  echo "    re-enable: lui ai enable"
  [[ "$prune" == true ]] || return 0

  local pkg_file="$AI_PACKAGES_FILE"
  local pkgs=()
  if [[ -f "$pkg_file" ]]; then
    while read -r p; do
      [[ -z "$p" || "$p" == \#* ]] && continue
      grep -qx "$p" "$ROOT/config/protected-packages" 2>/dev/null \
        && die "refusing to prune protected package: $p"
      pacman -Q "$p" >/dev/null 2>&1 && pkgs+=("$p")
    done < <(grep -vE '^\s*#' "$pkg_file" | grep -vE '^\s*$')
  fi
  local bytes=0
  while IFS= read -r -d '' f; do
    bytes=$((bytes + $(stat -c %s "$f" 2>/dev/null || echo 0)))
  done < <(find "$STORE" -maxdepth 1 -type f -name '*.gguf' -print0 2>/dev/null)

  echo "==> prune would remove:"
  echo "    packages: ${pkgs[*]:-(none installed)}"
  echo "    models:   $(size_human "$bytes") under $STORE"
  echo "    service files: /etc/systemd/system/llama-swap.service /etc/llama-swap /usr/lib/sysusers.d/luicipher-llama.conf"
  echo "    agents:   /usr/local/lib/goose, /usr/local/bin/goose*, /etc/environment.d/90-llm-ai.conf"
  echo "    the @models subvolume itself is kept."
  if [[ "$yes" != true ]]; then
    local ans
    read -r -p "Type 'prune' to confirm: " ans
    [[ "$ans" == "prune" ]] || die "aborted"
  fi
  if [[ ${#pkgs[@]} -gt 0 ]]; then
    sudo pacman -Rns --noconfirm "${pkgs[@]}"
  fi
  sudo rm -f /etc/systemd/system/llama-swap.service /usr/lib/sysusers.d/luicipher-llama.conf
  sudo rm -rf /etc/llama-swap
  sudo rm -rf /usr/local/lib/goose
  sudo rm -f /usr/local/bin/goose /usr/local/bin/goose-general /usr/local/bin/goose-code \
    /usr/local/bin/goose-hq /usr/local/bin/goose-research
  sudo rm -f /etc/environment.d/90-llm-ai.conf /etc/profile.d/90-llm-ai.sh
  sudo find "$STORE" -mindepth 1 -delete
  sudo systemctl daemon-reload
  echo "==> AI packages and weights removed; /etc/lui/ai.disabled stays so sync will not reinstall them"
}

cmd="${1:-status}"
[[ $# -gt 0 ]] && shift || true
case "$cmd" in
  status) cmd_status ;;
  sync) cmd_sync "$@" ;;
  run) cmd_run "$@" ;;
  bench) cmd_bench "$@" ;;
  audit) cmd_audit "$@" ;;
  cloud) cmd_cloud "$@" ;;
  enable) cmd_enable "$@" ;;
  disable) cmd_disable "$@" ;;
  help|--help|-h) usage ;;
  *) printf 'lui ai: unknown command: %s\n\n' "$cmd" >&2; usage >&2; exit 2 ;;
esac