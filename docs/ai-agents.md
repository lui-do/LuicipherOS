# AI agents and models (ADR-0002)

Local-first, system-wide. One model service, one model store, per-user sessions
and keys. Nothing here falls back to a cloud provider on its own.

## Files (declarative)

| Path | Purpose |
|---|---|
| `config/ai-packages` | optional AI package set (engine, router, Goose Desktop) |
| `config/models.json` | model manifest: repo, file, size, sha256, context, aliases |
| `install/environment.d/90-llm-ai.conf` | system-wide Goose defaults (no secrets) |
| `install/profile.d/90-llm-ai.sh` | mirror for non-systemd login shells |
| `install/goose-cli.sh` | fallback pinned Goose CLI (only if the package omits `/usr/bin/goose`) |
| `install/llama-swap.service` / `install/llama-swap/config.yaml` | model server |
| `config/ai-templates/` | merge templates for per-user OpenCode/Pi config (`lui ai setup-user`) |

Runtime stores (never in the repo):

- weights: `/var/lib/llm/models` (root-owned, `@models` subvolume)
- Goose: `~/.config/goose`, `~/.local/share/goose` (user-only, CLI and Desktop)
- OpenCode: `~/.local/share/opencode`
- Pi: `~/.pi/agent/sessions`
- per-user cloud keys: `~/.config/lui/ai.env` (mode 0600)

## Install / deploy

System pieces, as the admin account (`luci`), from a readable staging copy or
`~/LuicipherOS`:

```bash
sudo ./install/deploy-tree.sh     # publish /opt/LuicipherOS (both accounts resolve it)
lui sync --system                 # llama-cpp, llama-swap-bin, goose-desktop-bin, mise
./install/bootstrap.sh --ai-only  # service, config, goose CLI, env defaults, wrappers
lui ai status
lui ai sync --dry-run             # sources + ~40 GiB
lui ai sync                       # download + sha256 verify
```

`--ai-only` deploys the system AI pieces without stowing dotfiles into luci's
home. Per-user pieces, as `work`:

```bash
lui ai setup-user        # merge local provider/privacy keys into OpenCode+Pi (preserves your keys)

mise use -g node@lts
mise use -g npm:opencode-ai
mise use -g npm:@earendil-works/pi-coding-agent

lui ai run                  # Goose CLI, general model
goose-code                  # convenience wrapper (if installed)
opencode                    # uses llamacpp/coding from your merged config
pi                          # uses llamacpp/coding from ~/.pi/agent
```

`goose-desktop` and the CLI use the same `~/.config/goose`; verify after the
first launch with `goose info -v` and the Desktop Settings page. Do not use the
Flatpak build: its sandbox separates state.

## OpenCode (work profile)

OpenCode config is **merged, not stowed**, so an existing
`~/.config/opencode/opencode.json` (permissions, providers, keybinds) is never
overwritten. `lui ai setup-user` adds these keys and backs up the old file:

```json
{
  "share": "disabled",
  "openTelemetry": false,
  "model": "llamacpp/coding",
  "providers": {
    "llamacpp": {
      "name": "llama-swap (local)",
      "package": "@opencode/ai/providers/openai-compatible",
      "settings": {
        "baseURL": "http://127.0.0.1:12434/v1",
        "apiKey": "local"
      },
      "models": {
        "general": { "name": "Qwen3.5-9B (local)" },
        "coding": { "name": "Tiel-Coder-35B-A3B (local)" },
        "coding-hq": { "name": "Inkling 2 Mini (local, HQ)" },
        "research": { "name": "Qwen3.5-9B (local, tools)" }
      }
    }
  }
}
```

`share: disabled` is the important privacy bit; `openTelemetry: false` is the
second. `lui ai audit` verifies both.

Pi's config is merged by `lui ai setup-user` into `~/.pi/agent/` (provider
`llamacpp` added, other providers preserved, telemetry/analytics off).

## Model aliases

| Alias | Weights | Use |
|---|---|---|
| `general` | Qwen3.5-9B Q6_K | everyday chat/docs (small, fast) |
| `coding` | Tiel-Coder-35B-A3B UD-Q3_K_XL | fast coding loops |
| `coding-hq` | Inkling 2 Mini UD-Q4_K_M | quality coding/review |
| `research` | same file as `general` (Qwen3.5-9B) | web/curl/bash tool chains |

One large model is resident at a time; llama-swap swaps in ~10–15 s. Tune
context/quants with `lui ai bench` on the target. If the 20 GB card is tight,
spill expert layers to system RAM with `--n-cpu-moe N` (all experts:
`--cpu-moe`) — not to the SSD. llama.cpp's mmap mode can demand-page from disk,
but expert reads become random I/O and collapse tok/s; RAM offload is the
supported path.

## Cloud keys (explicit, per user)

Nothing cloud is installed system-wide. A user who wants a hosted model writes
their own key:

```bash
mkdir -p ~/.config/lui
cat > ~/.config/lui/ai.env <<'EOF'
GOOSE_PROVIDER__API_KEY=sk-...
OPENROUTER_API_KEY=sk-or-...
EOF
chmod 600 ~/.config/lui/ai.env

lui ai cloud openrouter anthropic/claude-sonnet-5.5
```

`lui ai run` always uses the local endpoint, regardless of what is in `ai.env`.
`lui ai cloud` is the only path that uses a hosted provider, and it fails if no
key is present instead of falling back.

## Disable / uninstall

```bash
lui ai disable             # stop the endpoint; keep packages and weights
lui ai enable              # restore
lui ai disable --prune     # preview + typed confirmation; removes packages,
                           # weights, service files, goose CLI, env defaults
```

`/etc/lui/ai.disabled` makes `lui sync --system` skip `config/ai-packages` so a
disabled stack is not reinstalled. The `@models` subvolume is kept; only its
contents are removed.