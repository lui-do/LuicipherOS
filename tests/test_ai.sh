#!/usr/bin/env bash
# tests/test_ai.sh — contract tests for scripts/ai.sh (`lui ai`).
# Seams:
#   1. status: manifest rows, aliases, present/missing state
#   2. sync --dry-run: plans downloads without network or sudo
#   3. sync --yes: downloads to the store, verifies sha256
#   4. run: exports the local provider/model/telemetry env and execs goose
#   5. alias resolution (coding-hq -> same weights)
#   6. enable/disable: admin flag + systemctl, packages/models untouched
#   7. audit: loopback + key placement checks
# Method: temp manifest/store/flag, mocked sudo/systemctl/curl/goose.
# USAGE: ./tests/test_ai.sh   (exit 0 = all pass)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI="$ROOT/scripts/ai.sh"
PASS=0; FAILN=0
ok()  { PASS=$((PASS+1)); echo "  ok: $1"; }
bad() { FAILN=$((FAILN+1)); echo "  FAIL: $1"; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/store" "$T/calls" "$T/home/.config"
export HOME="$T/home"
export XDG_CONFIG_HOME="$T/home/.config"
export LUI_AI_MANIFEST="$T/models.json"
export LUI_AI_STORE="$T/store"
export LUI_AI_DISABLED_FLAG="$T/disabled"
export LUI_AI_ENDPOINT="http://127.0.0.1:19999"
export LUI_GOOSE_BIN="$T/bin/goose"
export CALLS_DIR="$T/calls"
export PATH="$T/bin:$PATH"

SHA=$(printf 'hello' | sha256sum | awk '{print $1}')
cat > "$LUI_AI_MANIFEST" <<EOF
{"version":1,"models":[
 {"id":"general","aliases":["coding-hq"],"file":"general.gguf","repo":"test/general","source_file":"general.gguf","size_bytes":5,"sha256":"$SHA","license":"MIT","context":4096,"role":"test"},
 {"id":"coding","aliases":[],"file":"coding.gguf","repo":"test/coding","source_file":"coding.gguf","size_bytes":5,"sha256":"$SHA","license":"MIT","context":4096,"role":"test"}
]}
EOF

cat > "$T/bin/sudo" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-n" || "${1:-}" == "-v" ]]; then
  [[ "${SUDO_DENY:-0}" == "1" ]] && exit 1
  exit 0
fi
echo "sudo $*" >> "$CALLS_DIR/sudo"
if [[ "${1:-}" == "install" ]]; then
  for a in "$@"; do [[ "$a" == /etc/* ]] && exit 0; done
fi
if [[ "${1:-}" == "-u" ]]; then
  shift 2
  if [[ "${1:-}" == "env" ]]; then
    shift; while [[ $# -gt 0 && "$1" == *=* ]]; do shift; done
  fi
fi
exec "$@"
EOF
cat > "$T/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  is-active) echo active ;;
  is-enabled) echo enabled ;;
  *) echo "systemctl $*" >> "$CALLS_DIR/systemctl" ;;
esac
exit 0
EOF
cat > "$T/bin/curl" <<'EOF'
#!/usr/bin/env bash
case "$*" in *"/v1/models"*) exit 0 ;; esac
out=""; prev=""
for a in "$@"; do [[ "$prev" == "-o" ]] && out="$a"; prev="$a"; done
[[ -n "$out" ]] && printf 'hello' > "$out"
exit 0
EOF
cat > "$T/bin/goose" <<'EOF'
#!/usr/bin/env bash
echo "MODEL=$GOOSE_MODEL PROVIDER=$GOOSE_PROVIDER HOST=$GOOSE_PROVIDER__HOST TELEMETRY=$GOOSE_TELEMETRY_ENABLED KEY=${GOOSE_PROVIDER__API_KEY:-unset} ARGS=$*"
EOF
chmod +x "$T/bin/"*

run_ai() { bash "$AI" "$@" 2>&1; }

echo "== 1. status =="
printf 'hello' > "$T/store/general.gguf"
OUT=$(run_ai status)
[[ "$OUT" == *"general"*"ok"* ]] && ok "present model shows ok" || bad "status missing general/ok: $OUT"
[[ "$OUT" == *"coding"*"missing"* ]] && ok "missing model shown" || bad "status missing coding: $OUT"
[[ "$OUT" == *"coding-hq"* ]] && ok "aliases listed" || bad "aliases missing: $OUT"

echo "== 2. sync --dry-run =="
rm -f "$T/store/coding.gguf"
OUT=$(run_ai sync --dry-run)
[[ "$OUT" == *"1 model(s)"* ]] && ok "dry-run counts missing" || bad "dry-run count: $OUT"
[[ "$OUT" == *"https://huggingface.co/test/coding"* ]] && ok "dry-run prints source URL" || bad "no URL: $OUT"
[[ ! -f "$T/store/coding.gguf" ]] && ok "dry-run downloads nothing" || bad "dry-run wrote a file"

echo "== 3. sync --yes downloads and verifies =="
OUT=$(run_ai sync --yes)
[[ -f "$T/store/coding.gguf" ]] && ok "model written" || bad "model not written: $OUT"
[[ "$(cat "$T/store/coding.gguf" 2>/dev/null)" == "hello" ]] && ok "content matches source" || bad "content wrong"
[[ "$OUT" == *"ok"* ]] && ok "sync reports success" || bad "no success line: $OUT"

echo "== 4. run exports the local-only env =="
OUT=$(run_ai run)
[[ "$OUT" == *"MODEL=general"* ]] && ok "default model general" || bad "default model: $OUT"
[[ "$OUT" == *"PROVIDER=openai"* && "$OUT" == *"HOST=http://127.0.0.1:19999"* ]] \
  && ok "local provider/host pinned" || bad "provider env wrong: $OUT"
[[ "$OUT" == *"TELEMETRY=false"* ]] && ok "telemetry forced off" || bad "telemetry not off: $OUT"

echo "== 5. alias resolves to the same model =="
OUT=$(run_ai run coding-hq)
[[ "$OUT" == *"MODEL=coding-hq"* ]] && ok "coding-hq alias passed to goose" || bad "alias: $OUT"

echo "== 6. unknown model fails =="
OUT=$(run_ai run nonsense 2>&1); RC=$?
[[ "$RC" -ne 0 && "$OUT" == *"unknown model"* ]] && ok "unknown model rejected" || bad "unknown model accepted: rc=$RC $OUT"

echo "== 7. disable / enable toggles the flag and the unit =="
rm -f "$CALLS_DIR/systemctl"
run_ai disable >/dev/null
[[ -f "$LUI_AI_DISABLED_FLAG" ]] && ok "disable writes the flag" || bad "flag missing"
grep -q 'disable --now llama-swap' "$CALLS_DIR/systemctl" 2>/dev/null \
  && ok "disable stops the unit" || bad "systemctl disable not called"
run_ai enable >/dev/null
[[ ! -f "$LUI_AI_DISABLED_FLAG" ]] && ok "enable clears the flag" || bad "flag still present"
grep -q 'enable --now llama-swap' "$CALLS_DIR/systemctl" 2>/dev/null \
  && ok "enable starts the unit" || bad "systemctl enable not called"

echo "== 8. audit checks loopback and key placement =="
OUT=$(run_ai audit 2>&1)
[[ "$OUT" == *"loopback"* ]] && ok "audit confirms loopback" || bad "no loopback check: $OUT"
[[ "$OUT" == *"no API keys"* ]] && ok "audit checks /etc for keys" || bad "no key check: $OUT"

echo ""
echo "tests: $PASS passed, $FAILN failed"
[[ "$FAILN" -eq 0 ]]