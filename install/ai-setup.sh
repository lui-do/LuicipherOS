#!/usr/bin/env bash
# install/ai-setup.sh — deploy the system-wide AI pieces (ADR-0002).
#
# Run as the admin account (luci), unprivileged; this script escalates itself.
# It does NOT install packages (that is `lui sync --system`) and does NOT
# download model weights (that is `lui ai sync`). Idempotent.
#
# `install/bootstrap.sh --ai-only` calls this without touching dotfiles, which
# is how luci deploys the stack without stowing into luci's own home.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISABLED_FLAG="${LUI_AI_DISABLED_FLAG:-/etc/lui/ai.disabled}"

log() { echo "==> ai-setup: $1"; }
die() { echo "ai-setup: $1" >&2; exit 1; }

[[ "${EUID:-$(id -u)}" -ne 0 ]] \
  || die "run as the admin user (luci), not root; this script calls sudo itself"

if [[ -e "$DISABLED_FLAG" ]]; then
  log "AI stack disabled ($DISABLED_FLAG); nothing to do"
  exit 0
fi

if ! command -v llama-swap >/dev/null 2>&1; then
  die "llama-swap is not installed; run 'lui sync --system' first"
fi

log "unprivileged llama account"
sudo install -Dm644 "$ROOT/install/llama-swap.sysusers" /usr/lib/sysusers.d/luicipher-llama.conf
sudo systemd-sysusers /usr/lib/sysusers.d/luicipher-llama.conf

log "llama-swap config + unit"
sudo install -Dm644 "$ROOT/install/llama-swap/config.yaml" /etc/llama-swap/config.yaml
sudo install -Dm644 "$ROOT/install/llama-swap.service" /etc/systemd/system/llama-swap.service
sudo systemctl enable llama-swap 2>/dev/null || echo "  (llama-swap enable skipped)"

# Goose CLI from the same upstream release as goose-desktop-bin (the AUR CLI
# conflicts with the Desktop package). Both native apps use ~/.config/goose.
if [[ -f "$ROOT/install/goose-cli.sh" ]]; then
  bash "$ROOT/install/goose-cli.sh" || echo "  WARN: goose CLI install failed"
fi

log "local-only environment defaults (no secrets)"
sudo install -Dm644 "$ROOT/install/environment.d/90-llm-ai.conf" /etc/environment.d/90-llm-ai.conf
sudo install -Dm644 "$ROOT/install/profile.d/90-llm-ai.sh" /etc/profile.d/90-llm-ai.sh

log "model wrappers"
if [[ -x /usr/local/bin/goose ]]; then
  for pair in "general goose-general" "coding goose-code" "coding-hq goose-hq" "research goose-research"; do
    alias_name="${pair%% *}"; bin_name="${pair##* }"
    sudo tee "/usr/local/bin/$bin_name" >/dev/null <<EOF
#!/bin/sh
set -a
[ -r /etc/environment.d/90-llm-ai.conf ] && . /etc/environment.d/90-llm-ai.conf
set +a
GOOSE_MODEL=$alias_name
export GOOSE_MODEL
exec /usr/local/bin/goose "\$@"
EOF
    sudo chmod 755 "/usr/local/bin/$bin_name"
  done
fi

# The store must be the @models mount; never create it inside @.
if findmnt -M /var/lib/llm >/dev/null 2>&1; then
  sudo install -d -m755 /var/lib/llm/models
else
  echo "  WARN: /var/lib/llm is not a mount point; model store not created (ADR-0002)"
fi

log "done. Next: lui ai status; lui ai sync --dry-run; lui ai sync"