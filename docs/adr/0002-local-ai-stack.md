# ADR-0002: Local-first, system-wide AI stack (llama.cpp + Goose)

Date: 2026-11-19 | Status: accepted (approved by user 2026-11-19)

## Context

LuicipherOS has two real user profiles on the target desktop (`luci` = personal,
`work` = work) and is prepared for future users. The goal is a **system-wide** AI
layer, not per-user copies:

- Goose runs for every account, with CLI and Desktop sharing settings and sessions.
- Models are served once, system-wide, by a local engine.
- Default behaviour is local-only: results stay on disk, no silent cloud fallback,
  telemetry disabled or minimal.
- Three everyday models: general, coding, small research/tool-caller.
- Everything is declarative through `lui sync`, and can be removed by an
  administrator who does not want the feature.
- The work profile also uses OpenCode and Pi; both are installed per user via mise.

Target hardware: Ryzen 5 9600X, 32 GB RAM, **RX 7900 XT 20 GB (gfx1100)**, Arch.
The open boot/GPU issue (issue #11) is out of scope; this ADR must not change the
ESP, boot entries, `amdgpu` units, or `config/protected-packages`.

Model landscape checked 2026-11-19 (sources: Artificial Analysis tau3-Banking,
Sierra tau-bench, public GGUF/llama.cpp reports):

| Candidate | Verdict |
| --- | --- |
| Qwen3.8-27B (Aug 2026, Apache-2.0, 262K, vision) | Strong all-round 27B; replaced as `general` on 2026-11-23 |
| Inkling 2 Mini (Nov 2026, Apache-2.0, 1M, looped MoE 26.4B/3.4B) | `coding-hq`: better agentic coding, faster decode, 20 GB-class |
| Tiel-Coder-35B-A3B (MIT, 36B total / 3B active, 2026) | Fast agent-loop coder; weaker on the hardest tickets |
| Qwen3.5-9B (Apache-2.0, 262K) | Best small tool-caller (BFCL-V4 66.1, TAU2 79.1) |
| Gemma 4 31B | Rejected for agent use: llama.cpp tool-call bugs (calls returned as content) |
| GLM-5.3 / DeepSeek-V4 / Kimi K3 | Do not fit 20 GB |

Engine: Arch Extra ships `llama-cpp` 0.9.0 with dynamic backends (`ggml-vulkan`,
`ggml-hip`). On gfx1100, current measurements put ROCm slightly ahead on prompt
processing (~20%) but behind on token generation; Vulkan avoids HIP rebuild churn.

## Decision

### 1. Engine and service

- Packages: `llama-cpp` + `ggml-vulkan` (Extra), `llama-swap-bin` (AUR, prebuilt).
- `llama-swap` runs as a **system** service (not per-user), dedicated system user
  `llama` in groups `render`/`video`, bound to `127.0.0.1:12434` only.
- Config at `/etc/llama-swap/config.yaml`; models under `/var/lib/llm/models`
  (root-owned, read-only to the service).
- Unit conditions: `ConditionPathExists=/dev/dri/renderD128`,
  `ConditionPathIsMountPoint=/var/lib/llm`, `RequiresMountsFor=/var/lib/llm`,
  `After=graphical.target`. Models load lazily on first request.
- Hardening: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`,
  `ProtectHome=yes`, `ReadOnlyPaths=/var/lib/llm`.
- Vulkan is the default backend. `ggml-hip` stays an optional A/B experiment,
  never the default.

### 2. Models

Model weights are **data, not packages**. `config/models` is the source of truth
(alias, upstream repo, file, sha256, context, extra args). Downloads happen only
through `lui ai sync` with confirmation; `lui sync` never downloads weights.

Three weight sets, four aliases (≈41 GB total):

| Alias | Weights | Quant target | Role |
| --- | --- | --- | --- |
| `general` | Qwen3.5-9B | Q6_K (~7.5 GB), 64K ctx | Everyday chat/docs (small, fast) |
| `coding` | Tiel-Coder-35B-A3B | UD-Q3_K_XL (~16 GB) | Fast agent loops (OpenCode/Pi/Goose) |
| `coding-hq` | Inkling 2 Mini | UD-Q4_K_M (~16.6 GB), 24K ctx | Quality coding/review |
| `research` | Qwen3.5-9B (same file as `general`) | Q6_K | Web/curl/bash tool chains |

Only one large model is resident at a time (llama-swap, ~10–15 s swap). The exact
quant per alias is locked after `lui ai bench` on the target; if Q4 leaves too
little context, `coding-hq` moves to UD-Q3_K_XL or spills a few layers to RAM
(`-ngl` / `--n-cpu-moe`), measured rather than assumed.

### 3. Agents and shared state

- `goose-desktop-bin` (AUR, native, bundles CLI + Desktop) is the primary install.
  Native is chosen over Flatpak so CLI and Desktop share `~/.config/goose` and the
  session store. All Goose state is **user-only**; no `/etc` sessions, no keys.
- System defaults (no secrets) in `/etc/environment.d/90-llm-ai.conf`: local
  provider/host, default model `general`, telemetry off.
- Per-user opt-in overrides in `~/.config/lui/ai.env` (mode 0600, never committed,
  never stowed).
- OpenCode and Pi are installed per user with **mise** (system-wide package,
  per-user tool installs), configured against the same local endpoint.
- `lui ai` is the single entry point; thin wrappers (`goose-code`,
  `goose-research`, `goose-hq`) are convenience shims only.

### 4. Declarative integration and lifecycle

- `config/packages`: `llama-cpp`, `ggml-vulkan`, `mise`.
- `config/packages-arch`: `llama-swap-bin`, `goose-desktop-bin`.
- `install/bootstrap.sh` deploys system-owned files (llama-swap unit/config,
  environment defaults), like greetd — these are not stowable.
- `lui ai enable` / `disable`: `disable` writes `/etc/lui/ai.disabled`, stops and
  disables the endpoint, and makes `lui sync` skip the AI packages. Packages and
  models stay installed.
- `lui ai disable --prune`: the only definitive uninstall — removes packages
  through the guarded sync-prune path and deletes the model files after a second
  confirmation.
- Model storage is a separate `@models` Btrfs subvolume (see runbook), so 42 GB of
  weights never enters root snapshots.

### 5. Privacy and cloud policy

- Default provider is `http://127.0.0.1:12434`; no API keys in `/etc`.
- Telemetry pinned off: `GOOSE_TELEMETRY_ENABLED=false`,
  `OTEL_SDK_DISABLED=true`; OpenCode `"share": "disabled"` and
  `"openTelemetry": false`; Pi `PI_TELEMETRY=0` (exact variable verified in code).
- Sessions stay local and per-user: Goose (`~/.config/goose`,
  `~/.local/share/goose`), OpenCode (`~/.local/share/opencode`), Pi
  (`~/.pi/agent/sessions`).
- Cloud use is explicit and per user: the user adds their own key to
  `~/.config/lui/ai.env` and runs `lui ai cloud <provider>`. There is no automatic
  fallback; a failed local endpoint is an error, not a cloud request.
- `lui ai audit` reports active provider, endpoint, telemetry flags, session paths,
  and greps `/etc` for accidental keys.

### 6. Storage

`@models` is a new Btrfs subvolume at the top level, mounted at `/var/lib/llm`.
Nested subvolumes are not included in snapshots of `@`, so the model store is
excluded from Snapper automatically. The mount uses `nofail` so a missing
subvolume never blocks boot; the service additionally refuses to start unless
`/var/lib/llm` is a mount point, so weights can never silently land inside `@`.

Fresh installs must get the same layout: `install/archinstall-desktop.json` adds
`{ "mountpoint": "/var/lib/llm", "name": "@models" }` to the btrfs subvolume list
(archinstall then generates the fstab entry), and `install/bootstrap.sh` ensures
the mount point, ownership, and the `nofail,x-systemd.device-timeout=10s` options
(archinstall's `mount_options` apply per partition, not per subvolume). The 60 GiB
VM disk must be enlarged for real model weights; the target desktop already has
`@models` mounted (2026-11-19).

## Rationale and trade-offs

- **Vulkan over ROCm**: stable generation speed on gfx1100 and no monthly HIP
  rebuilds. Accepts slower prefill; agent work is decode-bound.
- **Weights vs packages**: pacman should not own 42 GB of changing model files with
  their own licences. A pinned manifest + checksum keeps installs small and makes
  removal explicit, while packages stay declarative in `lui sync`.
- **Four aliases, three downloads**: `general` and `research` share the
  Qwen3.5-9B file; `coding-hq` is the separate Inkling quality-coding model;
  `coding` is Tiel.
- **2026-11-23 update**: `general` moved to the small Qwen3.5-9B (everyday
  chat/docs; shared with `research`), and `coding-hq` is Inkling 2 Mini
  UD-Q4_K_M for quality coding. Earlier that day `general` briefly held the
  Inkling weights; the small/quality split keeps chat fast and coding strong.
  `--n-cpu-moe` is the VRAM spill path; SSD demand-paging is not a supported
  performance mode.
- **Native Goose Desktop**: the Flatpak sandbox separates state and breaks the
  "CLI and Desktop share everything" requirement.
- **System-wide engine, per-user agents**: one GPU queue and one model cache, but
  each profile keeps its own sessions and keys. Trade-off: a swap is global, and
  all local users can reach the loopback endpoint.
- **Default-on**: the OS ships the feature; `lui ai disable --prune` is the clean
  opt-out. Models are still an explicit download, so a fresh install stays light.

## Consequences

- New `scripts/ai.sh` (or `lui ai` subcommand) and `scripts/models.sh`, plus tests
  in `tests/test_lui.sh` / `tests/test_sync.sh` for the disable flag and manifest
  parsing.
- `install/archinstall-desktop.json` declares `@models` and `bootstrap.sh` verifies
  the mount, so ISO installs and the target stay identical.
- `sync.sh` gains the `/etc/lui/ai.disabled` check; prune semantics unchanged.
- README, `CONTEXT.md`, `AGENTS.md`, and `.agent/CONTINUITY.md` updated once the
  ADR is accepted.
- Target-only verification: `lui ai bench`, quant/context fit, Goose Desktop ↔ CLI
  session sharing, Pi telemetry variable. Not claimed for the VM or other hardware.
- No changes to the ESP, boot entries, `amdgpu-*` units, or `protected-packages`.
- Rollback: `lui ai disable --prune`, then unmount and delete `@models` (see below).

## Storage runbook (`@models`) — execute only after ADR approval

Run as the admin account (`luci`), on the target desktop. Additive and reversible;
no existing file is moved or deleted.

```bash
# 0. confirm device and filesystem UUID
findmnt -no SOURCE,FSTYPE,UUID /
sudo btrfs subvolume list / | grep -E '@(models)?$'

# 1. snapshot the config state (optional but cheap)
sudo snapper -c root create --description "before @models"

# 2. create the subvolume at the Btrfs top level (subvolid=5)
sudo mkdir -p /mnt/btrfs-root
sudo mount -o subvolid=5 /dev/mapper/root /mnt/btrfs-root
sudo btrfs subvolume create /mnt/btrfs-root/@models
sudo umount /mnt/btrfs-root

# 3. mount it at the model store
sudo mkdir -p /var/lib/llm
# append exactly one line, replacing <UUID> with the value from step 0:
# UUID=<UUID> /var/lib/llm btrfs subvol=/@models,compress=zstd,noatime,nofail,x-systemd.device-timeout=10s 0 0
sudoedit /etc/fstab
sudo systemctl daemon-reload
sudo mount /var/lib/llm
findmnt /var/lib/llm
```

Verification:

```bash
btrfs subvolume list / | grep models          # @models present
df -h /var/lib/llm                            # separate filesystem
ls /.snapshots/*/snapshot/var/lib/llm 2>/dev/null   # empty dirs, not model files
```

Rollback:

```bash
sudo umount /var/lib/llm
sudoedit /etc/fstab                           # remove the @models line
sudo systemctl daemon-reload
sudo mount -o subvolid=5 /dev/mapper/root /mnt/btrfs-root
sudo btrfs subvolume delete /mnt/btrfs-root/@models
sudo umount /mnt/btrfs-root
```

## Open items verified during implementation

- `goose-desktop-bin` really shares config and session directories with the CLI
  (if not, pin `goose-cli-bin` and point Desktop at the same dirs).
- Exact Pi telemetry variable and OpenCode config keys.
- `llama-swap` config schema and AUR package freshness.
- Quant/context fit on 20 GB and swap timing (`lui ai bench`).