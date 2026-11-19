# CONTINUITY.md (Operational Log)

Survival briefing for agents. Read this before acting, append after acting.
Newest entries first within each section; entries are ISO-8601 UTC.
Provenance tags: `[USER]`, `[CODE]`, `[TOOL]`, `[ASSUMPTION]`. Unknown: `UNCONFIRMED`.
Times marked (approx.) were reconstructed from terminal screenshots and journal timestamps.
Record architectural changes here.

On 2026-11-11 this log was union-merged from two diverged copies (one holding the October
history, one holding the November detail); no entry was dropped.

## [PLANS]
- 2026-11-20T00:05Z `[USER]` **Package TUI decisions (backlog, after AI stack).** Locked: (1) declarative-only
  — the TUI edits desired lists/requests and runs `lui sync`, never installs out-of-band;
  (2) write model = **option 3, request queue**: `work` (non-admin) writes
  `~/.config/lui/packages.request` (source, id, scope, note); `luci` reviews with
  `lui sync --system --review`, approves into `config/packages`, `config/packages-arch` or the
  flatpak lists, then syncs. User-scope flatpaks may go to a per-user overlay
  `~/.config/lui/flatpaks-user.list` read by `lui sync --user`; (3) mixed result list with source
  filters (repo / AUR / Flatpak), badges and installed/desired status; (4) full preview: version,
  repo, size, dependencies/permissions, AUR votes, and a canonical URL (archlinux.org, AUR,
  flathub.org) with an "open in browser" action; (5) Vicinae integration via
  `lui pkg search <q>` plus an "Add package" action; (6) tech choice deferred to a mockup —
  fzf + gum (extra; fast, bash-native) vs Python Textual (extra; prettier, heavier). Mockup to
  show both variants before implementation. `fzf 0.75`, `gum 2.0.2`, `python-textual 8.2.8` are in
  extra. Next implementation step remains AI step 3 (`config/models` + `lui ai`).
- 2026-11-19T22:55Z `[USER]` **Backlog: package-manager TUI with online search.** Wants a terminal UI
  to manage packages, with search across pacman, Flatpak and AUR. Design constraint agreed in
  discussion: it must stay declarative — search results are added to/removed from the `config/`
  lists and realized by `lui sync` (system scope as `luci`, user scope as the owning account),
  never installed out-of-band, otherwise `--prune` later flags them as extras. Candidate
  implementation: `lui pkg` (fzf + bash; `fzf` is not installed yet; `whiptail` is present).
  Alternatives considered: `pacseek` (AUR, ready-made but direct-install), `bauh` (heavy GUI),
  Python Textual (new runtime). Sources: `pacman -Ss` (repo), AUR RPC v5 (`curl`+python3),
  `flatpak search`. Preview via `pacman -Si` / AUR RPC / `flatpak remote-info`. Mockup-first.
  Not started; after the AI stack work.
- 2026-11-19T22:12Z `[USER]` **AI stack: `@models` must also exist on fresh installs.** Every
  ISO/netinstall install must create the `@models` Btrfs subvolume mounted at `/var/lib/llm`, so
  the system-wide model store exists out of the box. Implementation: add
  `{ "mountpoint": "/var/lib/llm", "name": "@models" }` to the btrfs subvolume list in
  `install/archinstall-desktop.json` (archinstall writes the fstab entry), then let
  `install/bootstrap.sh` create `/var/lib/llm`, set ownership, and add
  `nofail,x-systemd.device-timeout=10s` if needed (archinstall's `mount_options` are per-partition,
  not per-subvolume). Do this as part of ADR-0002 execution, not before approval. Note: the VM disk
  is 60 G and must be enlarged for real model weights. The target desktop already has `@models`
  (subvolid 475, mounted 2026-11-19).
- 2026-11-19T23:59Z `[USER]` **Blank-display follow-up - DO NOT LOSE THIS.** The user runs the DMUB
  early-load test first (docs/warm-reboot-action-plan.md, "The remaining item"). **When the result
  is reported, prepare whichever applies: (a) if DMUB errors come back 0, the late-load retirement
  change set (drop `blacklist amdgpu`, remove the `modprobe.blacklist=` kernel param, disable
  `amdgpu-late` + `amdgpu-unload-on-shutdown`, `mkinitcpio -P`, cold boot, verify display + 0 DMUB
  errors); or (b) if errors are non-zero, the initramfs slimming (the `kms` hook pulls GPU firmware
  into a 53 MB image for a driver that never loads).** Both are boot-critical and need the user's
  explicit go-ahead. Also still to be confirmed by that same test: whether the firmware's display
  survives at all (is the LUKS prompt visible on a cold boot).
- 2026-11-19T23:55Z `[USER]` **Backlog for the next sessions (user-specified order).** Boot issues
  are done for now; the remaining blank-display work is prepared in docs/warm-reboot-action-plan.md
  and needs a reboot. Topics to pick up next, in the user's order: (1) **AI agents and models -
  priority**; (2) Vicinae; (3) Quickshell; (4) `lui sync`; (5) Docker and Podman 'run' apps, for
  both system-wide and user-only scopes. Related open threads already in the tree: the rice-up /
  shared-palette pipeline (themes/ + `lui theme`, stage 2 procedural wallpaper + Themes menu still
  deferred, see docs/mockups/themes-v1.html), the WezTerm switch (config/packages declares wezterm +
  matugen + exfatprogs, pending `lui sync`), and the local-apps launcher entries
  (`config/local-apps`). Notes for whoever picks this up: `luci` is the admin account and `lui` is
  the CLI - keep the naming split; sync stays manual-only (LOCKED); and the per-user override layer
  is `~/.config/lui/hypr/overrides.lua` + `~/.config/lui/quickshell/tokens.json`.
- 2026-11-14T23:07Z `[USER]` **Plan for 2026-11-16:** (1) reboot -> verify
  `amdgpu.ppfeaturemask=0xffff7fff` is live in `/proc/cmdline` (it has been in
  `arch-lateload.conf` since 2026-11-14 but no boot has used it yet); (2) from now,
  record the reset reason after every boot (`journalctl -k -b | grep -m1 'Previous
  system reset'`) to watch for new `0x00800800` events under EXPO-off + ppfeaturemask;
  (3) then start #21 rice-up / shared-palette pipeline, building on the new
  `luicipher/` override layering. Quickshell tokens layer is verified working; bar
  baseline 190 MB with async plugin loading. 5 commits pending push (`git push
  origin main`).
- 2026-11-12T22:41Z `[USER]` Test plan agreed and written up as
  `docs/memtest-and-bios-test-plan.md`. Sequence: (1) MemTest86+ at **current** settings first, so
  it tests the machine as it fails; (2) then record the Ai Tweaker baseline in BIOS before changing
  anything; (3) then single-variable BIOS tests in order - Ai Overclock Tuner (EXPO) to Auto, Memory
  Context Restore to Disabled, Precision Boost Overdrive, Curve Optimizer, Power Supply Idle Control
  to Typical Current Idle, with SoC voltage observed only. **Decision rule: if MemTest86 reports any
  error, EXPO is disabled to Auto immediately** and MemTest86 is re-run to confirm. If MemTest86 is
  clean, EXPO is not the cause and the suspect list starts at Memory Context Restore / PBO / Curve
  Optimizer.
- 2026-11-12T22:41Z `[TOOL]` The LuicipherOS netinstall stick (14.4 GB DataTraveler,
  `LUICI_202610`) was formatted to FAT32 `MEMTEST` to serve as the MemTest86+ F6 report target.
  Its image was backed up first to `/home/work/luici-installer-backup.img` (2 GB) and verified with
  `blkid` (LABEL and iso9660 intact) and `fdisk` (both partitions present), so the installer is
  restorable with a single `dd`. The MemTest86+ stick is written and verified (`sdc`,
  `MT86PLUS_64`).
- 2026-11-12T14:11Z `[TOOL]` MemTest86 test plan finalised. Tool: **MemTest86+ v9.00** (GPL v2,
  2026-10-15), Linux x86_64 ISO `mt86plus_9.00_x86_64.iso.zip`, sha256
  `55d378c0d7d2e1a99edb6a1ff4bd5c78c179801b1f7cfe5893786c397bc19702`, written to USB with `dd`.
  Chosen because v9 adds a **Bus Stress Test aimed specifically at DDR5 EXPO/XMP training
  instability** ("signal integrity failures ... or XMP/EXPO training issues"), which is exactly the
  working hypothesis, plus an SPD integrity check. The machine is UEFI with **Secure Boot already
  disabled**, so the unsigned-image caveat does not apply. The USB route touches neither the ESP nor
  the LUKS disk; the `memtest86+-efi` package was rejected because it writes to `/boot` and adds a
  boot entry, which AGENTS.md forbids without an explicit instruction. Released 2026-10-15.
- 2026-11-12T14:11Z `[TOOL]` Machine facts for the test: board ASUS TUF GAMING B650E-PLUS
  WIFI, BIOS 4004
  (2026-09-16), UEFI, Secure Boot disabled, TPM2 present. Disks at the time of writing: `nvme0n1`
  931.5G KINGSTON SNV3S1000G (`nvme0n1p1` 1G vfat `/boot`, `nvme0n1p2` 860G LUKS -> btrfs root)
  and `zram0` 4G swap. **No USB device was attached**, so the stick still has to be plugged in and
  identified. ASUS boot menu is F8; BIOS setup is DEL.
- 2026-11-12T13:19Z `[TOOL]` Proposed next diagnostic, pending approval, cheapest first: (1)
  `sudo modprobe amd64_edac` to register memory controllers and expose correctable/uncorrectable
  error counters
  during normal use - no reboot, no config change, reversible; (2) MemTest86 from USB, which tests
  the memory at its BIOS-configured speed including EXPO, as the definitive test; (3) EXPO off in
  BIOS as a single-variable trial; (4) PSU swap only if the first three pass. Ruled out for the
  lockup: thermal (temps normal), GPU (no GPU error of any kind), OOM, suspend.

- 2026-11-11T11:11Z [TOOL] Proposed next test, pending approval: set `control=on` for the GPU's
  auxiliary PCI functions and observe DMUB errors, shutdown stalls and resets. Requires sudo but no
  reboot, package change, or boot-entry change; writes `auto` back to revert. **Executed on
  2026-11-11 12:28 and it froze the desktop; see [DISCOVERIES] 13:14Z. Retired.**

- 2026-11-11T10:05Z [USER] Wall-socket trial started with boot `bfd64b25` (2026-11-11 11:48 CET).
  Keep the desktop off the strip for about a week. Record each shutdown (time, uptime, whether the
  monitor had gone to sleep, whether it stalled) and each reset. No other change during the trial.

- 2026-11-11T10:05Z [TOOL] After the wall-socket trial, test the GPU PCI power-state path with a
  one-shot `pcie_port_pm=off` boot (no permanent edit), then `snd_hda_intel.power_save=0` as a
  runtime change. Deferred: firmware 20250708 downgrade (user declined) and long LTS comparison.

- 2026-11-10T23:10Z [TOOL] Track the AFK/DPMS no-wake failures separately from the hard reset;
  candidate fix is reducing or disabling hypridle DPMS/suspend, pending user approval.

- 2026-11-10T10:30Z [TOOL] Enforce the AGENTS.md v1.0 structure and keep this log current as
  architectural changes land.

- 2026-11-10T10:20Z [CODE] v0.1 remaining work: publish the netinstall ISO artifact and complete
  the target-machine bring-up. VM and ISO-loop smoke are already green (see `TESTING.md`).

- 2026-11-03T08:57Z [ASSUMPTION] Pending blank-start observations: Caps Lock response,
  monitor-only power cycle and another HDMI input/port. Nov 3 results are not reported.
  DisplayPort and shutdown-path experiments remain proposals, not established fixes.

- 2026-11-03T08:57Z [ASSUMPTION] Next project task proposed in conversation: audit the five
  sync-script items from the inventory document after the docs update; scope still to verify.

- 2026-10-31T20:39Z [USER] Continue issue #11: (1) normal boot with the enabled
  `amdgpu-late.service`; (2) delay variant (about 180 s) if it storms; (3) firmware 20250708
  vs 20260916 under late load; (4) PSU and AIB board model; (5) collect Hyprland crash reports.

- 2026-10-31T20:39Z [USER] TODO: decide the default Hyprland start: greetd currently runs
  `uwsm start hyprland` (5 s warning) while "Hyprland (uwsm managed)" has none. Compare the
  `Exec` lines in `/usr/share/wayland-sessions/*.desktop` and fix `install/greetd-config.toml`.

- 2026-10-31T20:39Z [ASSUMPTION] TODO: update `docs/dmub-coldboot-casefile.md` and `TESTING.md`
  with the Oct 31 results; fix the stale "unit DISABLED" statement.

- 2026-10-31T20:39Z [USER] TODO (cosmetic): rtkit, wireless-regdb, swaync config not found for
  user `work`; check dotfile stow state per account.

- 2026-10-31T10:50Z [USER] TODO: investigate mkinitcpio >= 42. Arch news says it needs manual
  intervention for TPM2-based LUKS unlocking. Boot entries use `cryptdevice=` (encrypt hook);
  whether TPM2 unlock is used is UNCONFIRMED. Read the news item before upgrading mkinitcpio.
  Installed mkinitcpio version UNCONFIRMED; it is in `config/protected-packages`.

- 2026-10-31T10:50Z [USER] TODO: create a repo wiki (start in `docs/wiki-draft/`) and document
  how to roll back the OS. Known facts to cover: Snapper snapshots cover only `@`; `/boot` is
  the ESP outside Btrfs and is not snapshotted; kernel downgrade = boot the LTS entry and
  `pacman -U` from the `@pkg` cache; snapshots suit config/file mistakes.

- 2026-10-31T10:50Z [USER] TODO: add dev-station packages (snapper, snap-pac, qemu-desktop,
  libvirt, virt-manager, edk2-ovmf, dnsmasq, swtpm, podman) to `config/packages` BEFORE any
  `lui sync --prune`; otherwise prune lists them as extras. Also add `dosfstools`.

- 2026-10-31T10:50Z [USER] TODO: inventory hand-installed packages/flatpaks with
  `./scripts/sync.sh --prune --dry-run` and sort into keep (add to lists) or remove.

- 2026-10-31T10:07Z [CODE] v0.1: target-machine installer + dotfiles + sync (README roadmap).

- 2026-10-31T10:07Z [CODE] v0.2: hardware profiles (`profiles/`), power/HiDPI, shell workspaces
  widget, tray, NotificationServer center (then drop swaync), screenshot tool decision.

- 2026-10-31T10:07Z [CODE] v0.3: optional Nix layer, `lui sync` as a binary, CI + VM matrix.

- 2026-10-31T10:07Z [CODE] Next on target: decide whether `amdgpu-late.service` helps; run
  `systemctl disable amdgpu-late` test (unrun per casefile). See the 2026-10-31T20:39Z entry:
  the unit is enabled on the desktop; its normal-boot test is now tracked in issue #11.

- 2026-10-31T10:07Z [CODE] Publish ISO only after one VM boot of the built artifact reaches
  archinstall (already met per TESTING.md; publish itself UNCONFIRMED).

- 2026-10-06T13:20Z [CODE] Keep the `amdgpu` late-load workaround until upstream fixes the DMUB
  cold-boot firmware regression; then unpin `linux-firmware`/`linux-firmware-amdgpu`.

- 2026-09-21T20:00Z [USER] v0.2 scope candidates: hardware profiles, power/HiDPI, shell
  notification center (to retire swaync), HiDPI monitor overrides, optional Nix layer (v0.3).

- 2026-09-21T20:00Z [CODE] v0.3 candidates: `lui sync` as a binary, CI plus VM test matrix.

## [DECISIONS]
- 2026-11-19T22:30Z `[USER]` **ADR-0002 approved: local-first, system-wide AI stack.** Engine =
  `llama-cpp` + `ggml-vulkan` (Vulkan default; ROCm only an opt-in A/B), routed by `llama-swap`
  as a hardened system service on `127.0.0.1:12434` under the unprivileged `llama` account.
  Weights are data, not packages: `config/models` + `lui ai sync` (sha256), stored on the
  `@models` subvolume at `/var/lib/llm`. Three weight sets, four aliases (`general`, `coding`,
  `coding-hq` = alias of general, `research`). Goose CLI + Desktop = native `goose-desktop-bin`
  so settings/sessions are shared and user-only. OpenCode and Pi are per-user via system-wide
  `mise`. Cloud keys are per-user only (`~/.config/lui/ai.env`, 0600); no automatic fallback;
  telemetry pinned off. `lui ai disable` only stops the endpoint; `lui ai disable --prune` is the
  only definitive uninstall. Fresh installs must create `@models` from
  `install/archinstall-desktop.json`. Stale boot note: storage on the target is already done
  (2026-11-19).
- 2026-11-15T14:10Z `[USER]` **Hypothesis from live evidence: warm reboots hang POST with amdgpu
  loaded; the driver must be unloaded before reboot.** The 2026-11-15 automated-boot test reboot
  produced a completely dead warm boot (no ASUS logo, no menu, Caps Lock dead = UEFI POST never
  completed); journal `fdb07937` ends 14:54:13, recovery via power-hold cold boot, and **the new
  automated late-load chain itself worked perfectly** (unit finished 15:04:01, ~179 s, DMUB clean,
  greetd up, login screen visible). Mechanism: a cold boot power-cycles the GPU; a warm reboot does
  not, so a GPU left mid-transaction breaks UEFI GOP init; `modprobe -r` performs a proper
  driver-side device reset. Response: new `install/amdgpu-unload-on-shutdown.service` (oneshot; on
  stop, retries `modprobe -r amdgpu` for ~24 s after greetd/user sessions are down, never blocks
  shutdown), wired into bootstrap.sh next to amdgpu-late; AGENTS boot/guardrail/params sections
  rewritten to the automated reality. NOT YET DEPLOYED - needs user to install+enable as luci, then
  a warm-reboot test decides it: visible POST after reboot = hypothesis confirmed.
- 2026-11-15T13:38Z `[USER]` **Boot path changed (user-directed): late-load fully automated.**
  `amdgpu-late.service` gains `ExecStartPre=/usr/bin/sleep 150` (the proven manual ~190 s wait,
  automated). Boot entry `arch-lateload.conf` loses `systemd.mask=amdgpu-late.service 3`; keeps
  `amdgpu.runpm=0 amdgpu.ppfeaturemask=0xffff7fff modprobe.blacklist=amdgpu`.
  `loader.conf` gains `default arch-lateload.conf` (without it the alphabetical default is the
  storm-prone plain `linux` entry - dangerous for unattended/blind boots). Verified preconditions:
  default target graphical, greetd enabled as display-manager, soft blacklist present,
  modprobe-explicit load bypasses blacklist (same as the manual procedure). Revert: restore
  `/root/arch-lateload.conf.bak` + re-add mask+3. Motivation: reboot blindness - the monitor may
  not show the LUKS prompt (GOP/HDMI), so the user must not depend on typing the manual dance
  blind; one blind passphrase + a timed service brings the display up by itself.
- 2026-11-15T12:48Z `[USER]` **Naming rule: LUI.cipherOS -> everything created is `lui`, never
  `luci`.** Applied repo-wide and live: `.desktop` prefix `luci-local-` -> `lui-local-`
  (regenerated), user-override root `~/.config/luicipher/` -> `~/.config/lui/` (moved, files
  intact), the Quickshell palette token `property var luci` -> `lui` (shell.qml + swayncIndicator +
  README + wiki draft - the pending token question, now answered), mockup `luci theme` -> `lui
  theme`. Legit exceptions kept: the actual admin account `luci` (creds example, inventory docs, the
  AGENTS guardrail, `docs/rename-admin-account.md` remains the deferred path to fix that too), the
  `LuicipherOS` brand string and its headers, and historical log entries. During the migration a
  batch `cp a b c $ROOT/` dumped files into the deployed repo root and overwrote its README.md -
  caught by residual-grep, README restored via `git checkout`, strays removed; lesson logged: sync
  the deployed tree only via commit + fetch/reset with explicit paths.
- 2026-11-14T22:59Z `[USER]` **Shell config layering implemented** (the per-user half of #18, done
  early): shared base stays stow-managed; per-user overrides live at
  `$XDG_CONFIG_HOME/luicipher/<app>/` and are NEVER stow-managed. Hyprland: `hyprland.lua`
  ends with a guarded `dofile` of `luicipher/hypr/overrides.lua` (last-wins). Quickshell:
  `shell.qml` merges defaults <- shared `tokens.json` <- user
  `luicipher/quickshell/tokens.json` via two `FileView`s with `watchChanges` (hot reload).
  Chosen over env vars (option B) for the community story and the future palette pipeline
  (#21/#22). Functionally verified on the live session: border_size 2 -> override 6 -> 2;
  quickshell parsed a live barHeight/accent override and survived config reload; the demo
  override reverted to base. API facts learned the hard way: `Quickshell.configPath()` is
  deprecated and resolves inside the shell dir (build paths from `Qt.environment` instead);
  Quickshell's `LazyLoader` is a QtObject (not Item, no `source`/`onLoaded`) so bar rows
  stay `Loader` with `asynchronous: true` and LazyLoader is for on-demand windows.
- 2026-11-14T22:34Z `[USER]` **Shell decided: stay on Hyprland + Quickshell** (issue #16 closed with
  the rationale). Quickshell wins on the two things that mattered - the customisability ceiling and
  the native Hyprland integration (screencopy window previews / live switcher) - and has zero
  migration cost since the bar and a plugin host already exist. AGS's only edges (lower RAM floor,
  more maturity) do not outweigh what would be lost, and the RAM gap is <0.5% of 31 GB and
  recoverable with documented Quickshell techniques. This unblocks #21 (Hyprland rice-up / palette
  pipeline) and #22 (Vicinae theming), both of which build on the Quickshell base.
- 2026-11-11T21:43Z `[USER]` Renamed the CLI from `luci` to `lui`; `lui` is also the GitHub owner
  handle, and `luci` collided with the admin account name. Scope was surgical because "luci" means
  four different things in this repo: the **CLI** (renamed: `scripts/lui.sh`,
  `/usr/local/bin/lui`, `LUI_ROOT`, `LUI_VERSION`, `lui sync|status|root`), the **admin user
  account** (untouched: `archinstall-desktop.creds.example.json`, the bring-up runbook, the
  inventory doc, `config/flatpaks-user.list`), the **Quickshell palette token** (`property var
  luci` in `shell.qml` / `swayncIndicator.qml`; **not** renamed, pending a separate decision), and
  the project name `LuicipherOS` (untouched). Earlier entries in this log were updated to the new
  CLI name for consistency; the rename changes no behaviour.

- 2026-11-11T21:36Z `[USER]` Ship a real `lui` command instead of documenting a repo path:
  `scripts/lui.sh`, installed to `/usr/local/bin/lui` by `bootstrap.sh`. `lui sync` is the
  single reconcile entry point; `lui status` is the read-only preview. Tree resolution is
  `$LUI_ROOT` -> `/opt/LuicipherOS` -> the tree the script lives in -> `~/LuicipherOS`, chosen so
  the same installed copy keeps working when the tree later moves to a shared system location
  (the multi-user plan). The CLI refuses to run as root, matching the AGENTS.md rule that sync runs
  as the daily account and calls `sudo` itself. Sync stays manual-only: no timer, unit or hook.
- 2026-11-11T21:36Z `[USER]` Declare `jq`, `sudo`, `mkinitcpio`, `btrfs-progs` and `efibootmgr` in
  `config/packages`. `jq` was an undeclared extra, so `lui sync --prune` would have uninstalled a
  general-purpose tool that plugins and scripts reach for. The other four were already in
  `protected-packages` (never pruned) but undeclared; declaring them makes `lui status` honest.

- 2026-11-11T16:05Z [USER] Two clones are intentional, not drift: `/home/work/LuicipherOS` is the
  **live/deployed** copy that the `~/.config` stow symlinks resolve into, and this clone
  (`/home/work/dev/personal/projects/IT/LuicipherOS`) is **development**. Dotfile changes made here
  do not affect the running desktop. Change flow is dev -> commit/push -> `git pull` in the deployed
  clone, or an explicit copy when the user asks for it. Never edit the deployed clone by assumption.

- 2026-11-11T15:50Z [USER] Remove the 12-minute DPMS-off and 30-minute suspend listeners from
  `hypridle.conf`; keep only the 10-minute lock. Reason: every DPMS wake risks the reproduced
  D3hot->D0 refusal, and the user's response to a dead screen is a hard power-off, which feeds the
  cold-boot DMUB problem. Reversible by re-adding the two listeners; the old text is kept as a
  comment in the file.

- 2026-10-31T10:30Z [USER] Desktop snapshots: Snapper + snap-pac chosen over Timeshift
  (Timeshift expects an `@`/`@home`-only layout; this system also has `@log`, `@pkg`,
  `@snapshots`). Dev station: libvirt/QEMU VM for installer/boot tests, Podman container for
  script tests.

- 2026-10-31T10:07Z [CODE] Locked in grill (CONTEXT.md): Vicinae launcher (SUPER+Space), fuzzel
  fallback, Quickshell bar, Tabby, grim+slurp -> Gradia, swaync kept for v0.1, native Lua
  Hyprland config, yay-bin, split flatpak scopes, manual-only sync.

- 2026-10-31T10:07Z [USER] Documentation standard: AGENTS.md (blueprint, fixed section order) and
  `.agent/CONTINUITY.md` (this log); Unified Agent Prompts v1.0.

- 2026-10-06T13:15Z [CODE] Soft-blacklist `amdgpu` and load it late via `amdgpu-late.service` on
  AMD hardware only, to survive the Navi31 DMUB cold-boot race without blocking VMs/Intel/NVIDIA.

- 2026-10-06T10:09Z [CODE] amdgpu late-load unit added for the cold-boot DMUB race (AMD only);
  verdict pending target test.

- 2026-10-04T16:45Z [CODE] Czech QWERTY default (Hyprland cz+qwerty, console cz) with dual
  workspace binds for the Czech number row and Alt+Shift layout toggle.

- 2026-10-04T14:56Z [CODE] Installer falls back to a geo mirror on sync failure and retries once.

- 2026-10-04T10:33Z [CODE] Czech QWERTY is the default layout (`cz+qwerty` in Hyprland, `cz`
  console); workspace binds follow the Czech number row, and `Alt+Shift` toggles layout.

- 2026-10-02T21:11Z [CODE] Flatpak declarations are split into `flatpaks-system.list` and
  `flatpaks-user.list`; `flatpaks.list` remains legacy system-scope compatibility only.

- 2026-10-02T19:11Z [CODE] Helium-only browser (`helium-browser-bin`), Firefox removed;
  greetd + tuigreet login; yazi picker shipped dormant opt-in; HyprCapture on HOLD.

- 2026-09-28T01:23Z [CODE] The netinstall ISO fetches packages at install time; none are baked
  in. Live-session script fixes require copying the updated installer from the clone.

- 2026-09-26T14:59Z [CODE] archinstall JSON stays `silent: false` for first runs. `sector_size`
  must be an object, the btrfs size must be explicit GiB, and ESP requires the `esp` flag.

- 2026-09-26T14:59Z [CODE] `bootstrap.sh` backs up conflicting stow targets to
  `~/.config-backup/` and retries rather than aborting on first-boot autogenerated files.

- 2026-09-22T21:04Z [CODE] Credentials are supplied out-of-band via `/tmp/creds.json`; the
  example file is a template only and real hashes are never committed.

- 2026-09-21T20:00Z [USER] ADR-0001 locked: Arch + declarative scripts for v0.1, not NixOS or
  LFS. Nix is an optional v0.3 layer; LFS is a learning side-quest only.

- 2026-09-21T20:00Z [USER] Locked stack: Vicinae primary (SUPER+Space) with fuzzel fallback,
  custom Quickshell bar plus plugin host, Tabby terminal, Gradia screenshots, swaync retained until
  a shell notification center exists, Hyprland native Lua only.

- 2026-09-21T20:00Z [USER] Sync is manual-only, add-only by default; prune is explicit,
  previewable, confirmed, and guarded by `config/protected-packages`. No auto-sync units.

- 2026-09-21T20:00Z [USER] AUR surface stays tiny; `yay-bin` is the default helper, `paru`
  supported. Hyprland, lock, portals, and drivers remain pacman-owned (PAM/SUID and GL constraints).

- 2026-09-21T00:00Z [CODE] ADR-0001: Arch + declarative scripts for v0.1; Nix optional in v0.3;
  LFS learning only. Time of day UNCONFIRMED (date from ADR).

## [PROGRESS]
- 2026-11-19T23:25Z `[TOOL]` **AI step 4 implemented: Goose + mise + user-only state.** Added
  `mise` (Extra) to `config/packages`, `goose-desktop-bin` to `config/packages-arch` and
  `config/ai-packages`. The AUR `goose-cli-bin` conflicts with `goose-desktop` and the Desktop
  package deletes `/usr/bin/goose`, so `install/goose-cli.sh` installs the matching **1.60.1**
  upstream CLI tarball (b2sum-pinned) to `/usr/local/lib/goose` + `/usr/local/bin/goose`; both
  native apps share `~/.config/goose`. `install/environment.d/90-llm-ai.conf` pins local provider,
  `GOOSE_MODEL=general`, telemetry off, `PI_TELEMETRY=0`; `install/profile.d/90-llm-ai.sh` mirrors
  it for login shells. `bootstrap.sh` deploys those, generates `goose-general/code/hq/research`
  wrappers, and stows `dotfiles/pi`. OpenCode config is deliberately **not stowed** (it would
  overwrite the existing `~/.config/opencode/opencode.json` permissions); `docs/ai-agents.md` has
  the merge snippet with `share: disabled` + `openTelemetry: false`. Pi config (provider, default
  `coding`, telemetry/analytics off) is stowed from `dotfiles/pi/.pi/agent/`. Added
  `docs/ai-agents.md` (paths, deploy, mise commands, cloud-key policy, disable/prune). Live
  deployment of this step is pending; model download still ~40 GiB as `luci`. System deploy is
  split into `install/ai-setup.sh` + `bootstrap.sh --ai-only`, so luci can deploy the AI pieces
  without stowing dotfiles into luci's home. `install/deploy-tree.sh` publishes the canonical
  tree to `/opt/LuicipherOS` (root-owned, world-readable) so both accounts and future users
  resolve one non-stale tree; `lui` already prefers it.
- 2026-11-19T23:20Z `[TOOL]` **AI step 3 implemented: model manifest + `lui ai`.** New
  `config/models.json` pins the exact upstream GGUF files, sizes and sha256 (read from the HF API):
  `general` = unsloth/Qwen3.8-27B-GGUF UD-Q4_K_XL (17,659,407,264 B, `2a5f3565...`), `coding` =
  peculiar-ragdoll/Tiel-Coder-35B-A3B-GGUF UD-Q3_K_XL (16,845,533,568 B, `2e11a195...`),
  `research` = unsloth/Qwen3.5-9B-GGUF Q6_K (7,458,301,152 B, `91898433...`). New
  `scripts/ai.sh` (`lui ai`): `status`, `sync` (admin; download to `.part`, sha256 verify, atomic
  move), `run` (per-user; local OpenAI provider, `GOOSE_TELEMETRY_ENABLED=false`,
  `OTEL_SDK_DISABLED=true`), `bench`, `audit`, `cloud` (explicit per-user key, no fallback),
  `enable`/`disable`/`disable --prune`. `config/ai-packages` is the optional package set;
  `/etc/lui/ai.disabled` makes `ensure-packages.sh` filter it. Also fixed `ensure-packages.sh` to
  honor `IgnorePkg`/`IgnoreGroup` (see the firmware note below) and fixed a delimiter bug where
  empty alias fields shifted manifest columns. Tests: test_ai 20/20, test_lui 22/22,
  test_sync 33/33. Live model download not run yet (~40 GiB; needs `luci`).
- 2026-11-19T23:47Z `[USER]` **`lui sync --system` run completed, but it overrode the firmware
  pin.** The full system reconcile succeeded (AUR rebuilds + flatpak system updates), and pacman
  installed `linux-firmware` and `linux-firmware-amdgpu` **20260916-1 -> 20261019-1** despite the
  deliberate `IgnorePkg` pins, because `ensure-packages` explicitly names them. Both initramfs
  images were rebuilt (linux + linux-lts) and `linux-firmware-amdgpu` is now 20261019 in the next
  boot. This is a real change to the DMUB/GPU firmware under the closed boot workaround: do not
  revert it without an explicit decision; observe the next boot (DMUB/power-gate error count) when
  convenient. `ensure-packages.sh` now filters `pacman-conf IgnorePkg` so sync can never repeat
  this. Also: the `vicinae-bin` upgrade's `modprobe uinput` failed because the running kernel
  (7.3.4) and installed modules (7.3.5) differ; expected to resolve on the next reboot.
- 2026-11-19T22:45Z `[TOOL]` **`lui sync` multi-user scope split implemented.** `work` is
  intentionally non-admin (sudo denied; the earlier wheel membership does not grant it), so sync
  now has explicit scopes: `--system` (pacman/AUR + system flatpaks; admin `luci`, sudo inside),
  `--user [ACCOUNT]` (user flatpaks + launcher entries; current account, no sudo; another
  account via `sudo -u` from the admin), and plain `lui sync` (system+user when admin rights are
  present, otherwise user only with the exact `--system` command printed). Prune is per scope;
  `lui status` previews both read-only without sudo. `ensure-flatpaks.sh` gained
  `--system|--user`. Tests: test_lui 21/21, test_sync 33/33 (new cases: system-only, user-only,
  `--user ACCOUNT`, non-admin fallback). ISO wiring: `install/archinstall-desktop.json` now
  declares `@models` at `/var/lib/llm`, and `luicipheros-install` prints the scoped post-install
  commands (`--system` as luci, `--user` per account). Docs updated in AGENTS.md + CONTEXT.md.
- 2026-11-19T22:12Z `[TOOL]` **Target desktop: `@models` subvolume created and mounted.** Ran the
  ADR-0002 storage runbook as admin account `luci`: created Btrfs subvolume `@models` at the top
  level (subvolid 475), mounted at `/var/lib/llm` via `/etc/fstab` with
  `subvol=/@models,compress=zstd,noatime,nofail,x-systemd.device-timeout=10s`. Verified
  `findmnt` reports `/dev/mapper/root[/@models]` and `df` shows 658 G free. No existing data was
  moved; snapshots of `@` exclude nested subvolumes. Only the storage step is done - engine,
  packages, models and agents are still pending ADR-0002 approval.
- 2026-11-15T13:04Z `[TOOL]` **Ricing stage 1 built: theme pipeline core.** New `themes/` dir with
  the six signed-off presets (mocha, nord, tokyo-night, gruvbox, everforest, rose-pine - keys mirror
  the Quickshell tokens); `scripts/theme.sh` + `lui theme` subcommand (list/show/set/reset/set
  wallpaper <img> via matugen with defensive tone mapping; matugen path UNTESTED until installed);
  set merges ONLY palette keys into the per-user tokens.json (barHeight and other user keys
  preserved - proven), reset drops just the palette. Tests: `tests/test_theme.sh` 7/7 (fixtures in
  temp tree/XDG_CONFIG_HOME), test_lui 18/18, test_sync 17/17. `matugen` declared in config/packages
  (installs on next lui sync as luci with LUI_ROOT set, or plain `sudo pacman -S matugen`). Kernel
  upgrade to 7.3.4.arch1-2 confirmed installed (running arch1-1 until reboot); -Syu showed only 3
  kernel packages were actually pending - the earlier 169 count was stale; system is now consistent,
  pending = the 2 [ignored] firmware pins.
- 2026-11-15T12:33Z `[USER]` **Ricing phase started (mockup-first).** Requirements given: (1) a
  theme **menu** with presets plus **generate-theme-from-wallpaper**; (2) asked whether the
  pipeline can also **generate wallpapers** - answer is yes, two ways: procedural
  (palette->gradient, instant/offline) and AI (demonstrated live: docs/mockups/assets/
  wall-ai-1.png and wall-ai-2.png, generated during mockup build; ~5 MB each,
  locally kept, gitignored via docs/mockups/.gitignore to avoid touching the user's
  pending root .gitignore changes); (3) one **shared base for ALL users**, with
  **work** additionally carrying a keyboard-first **Productivity profile** (named
  workspaces, 24px bar, 1px borders, cheat sheet) purely in the override layer.
  Process rule set by the user: iterate HTML mockups first; configs change only after
  sign-off. First mockup: docs/mockups/themes-v1.html (menu, 3 desktop states, pipeline
  diagram, procedural + AI wallpapers, 5 open questions Q1-Q5 in-page).
- 2026-11-15T10:21Z `[TOOL]` **Warranty report created for Alza**:
  `docs/warranty-report-2026-11-15.html` (source, committed) + bilingual PDF (Czech first, English
  second) at `docs/warranty-report-2026-11-15.pdf` (gitignored artifact per `docs/*.pdf` rule).
  Regenerate: `helium-browser --headless=new --no-sandbox --disable-gpu
  --user-data-dir=/tmp/helium-pdf --print-to-pdf=docs/warranty-report-2026-11-15.pdf
  --no-pdf-header-footer docs/warranty-report-2026-11-15.html`. Contains: components + board serial,
  event timeline with reset-register codes (incl. the 15-Nov UEFI-setup freeze), completed
  diagnostics (memory/ thermal/EXPO-off/software excluded), assessment (PSU/VRM/CPU), and the
  three-point request. **Placeholders left for the user to fill: invoice number, handover date,
  contact.**
- 2026-11-14T22:26Z `[TOOL]` The five untracked project items from the original 7-item list are now
  GitHub issues, so the whole backlog is visible: **#18** shared multi-user settings tree
  (correctness item, supersedes the per-user-clone model), **#19** `luci update` one-word system
  update + notification (depends on #18), **#20** replace Tabby with a terminal that has SSH/remote
  workflow, theming and a borderless mode (kitty excluded by AGENTS.md), **#21** rice Hyprland + a
  GUI/TUI config tool (note: every mainstream Hyprland GUI editor targets the legacy .conf format,
  so it fights the native-Lua lock), **#22** Vicinae theming (the deferred half; apps half done via
  config/local-apps). All labelled `enhancement` + `needs-triage`, cross-linked: #19 -> #18, #21 and
  #22 -> #16 (shell decision). This closes the tracking gap where 5 of the 7 items lived only in
  conversation.
- 2026-11-14T22:19Z `[TOOL]` `generate-local-apps` is now wired into the CLI and the reconcile. `lui
  sync` runs it automatically on the add-only path (so `config/local-apps` is realized every sync),
  and a new `lui local-apps [--remove]` subcommand drives the generator directly for targeted use.
  `sync.sh` dry-run now announces it too. Both test suites updated and green: `test_lui.sh` 18 (adds
  delegation + `--remove` pass-through), `test_sync.sh` 17 (fixture now stubs
  `generate-local-apps.sh`). AGENTS.md documents the whole flow (usage block, a dedicated Local apps
  paragraph, and an extensibility hook). **The installed `/usr/local/bin/lui` still predates this**,
  so the user must reinstall it (`sudo install -Dm755 <tree>/scripts/lui.sh /usr/local/bin/lui`) to
  get the `local-apps` subcommand; `config/local-apps` + `scripts/generate-local-apps.sh` are in the
  tree, and the 4 entries are already generated in work's live `~/.local/share/applications/`.
- 2026-11-14T22:07Z `[TOOL]` Vicinae's "missing ~/.local/bin apps" problem solved. Root cause
  confirmed: Vicinae is a desktop-entry launcher that reads .desktop files from the XDG
  applications dirs, not $PATH; the user's ~/.local/share/applications/ had no .desktop files, so
  none of the 21 tools in ~/.local/bin were visible. Of those 21, only 4 are launcher-worthy apps
  (TUICommander.AppImage, tuios, slk, vi-sql); the rest are CLI utilities (pip*, odf*/xml2odf/
  mailodf/csv2ods, pymupdf, slack-mcp, mise) deliberately excluded. Added `config/local-apps`
  (declarative: `<basename> [Display Name]`) and `scripts/generate-local-apps.sh` (idempotent,
  writes managed `luci-local-*.desktop` files with Terminal=true and `X-LuicipherOS=generated`,
  and a `--remove` to clean up; never touches user-authored entries). Generated the 4 entries in
  work's live ~/.local/share/applications/; all validate. The theming half of this task (adapt
  Vicinae to the shell/Hyprland palette) is deliberately deferred, per the user.

- 2026-11-11T21:36Z `[TOOL]` Delivered issue #5. Added `scripts/lui.sh` (subcommands `sync`,
  `status`, `root`, `version`, `help`; EUID guard; runtime tree resolution), `tests/test_lui.sh`
  (11 checks, all pass), and a bootstrap step installing the CLI to `/usr/local/bin/lui`. Declared
  five packages in `config/packages`. Static checks pass, `tests/test_sync.sh` still 17/17. The
  live `lui status` on the target now reports 2 pacman extras (down from 3): `python-rich` and
  `yay-bin-debug`, both undeclared leftovers rather than missing declarations.

- 2026-11-11T21:17Z `[TOOL]` Filed the 2026-11-11 findings as GitHub issues. New: **#13** instant
  `0x00800800` platform resets (`bug`, `needs-triage`), **#14** `03:00.2` D3hot->D0 refusal and GPU
  wedge (`bug`, `ready-for-human`), **#15** move the session lock to after resume (`bug`,
  `ready-for-agent`), **#16** shell/compositor evaluation (`enhancement`, `needs-triage`), **#17**
  wall-socket trial (`needs-info`). The lockscreen item was **not** duplicated: **#12** already
  tracked it, so the root cause, the applied fix (`31dc053`), the remaining manual-suspend exposure
  and the closed checklist were added there as a comment. Open issues now: 11-17 plus 2-5, 8-10.

- 2026-11-11T21:10Z `[TOOL]` Reconciled the two diverged working copies with origin. The dev clone
  was rebased onto `origin/main` (`bb7815f`); its local `AGENTS.md` and untracked
  `.agent/CONTINUITY.md` were replaced by origin's versions and then union-merged back. `AGENTS.md`
  now carries origin's blueprint plus the local-only guardrails. `CONTINUITY.md` is a union of both
  copies: 151 entries, verified zero dropped against either source, deduped and re-sorted
  newest-first, tags normalised to plain `[TAG]`. Committed as `08cecbb`. The deployed clone was
  reset to that commit (its `c9bca0a` had been rewritten by the rebase); both clones now match and
  are clean. `git config core.filemode false` was set in the dev clone, which removed 160
  mode-only phantom changes from `git status` without altering any file.

- 2026-11-10T23:10Z [TOOL] Read-only investigation of the 2026-10-27 shutdown photos and a
  56-boot reset-reason census. No BIOS, package, graphics config, boot entry, suspend, or GitHub
  write was performed.

- 2026-11-10T10:30Z [TOOL] Rewrote `AGENTS.md` to the v1.0 required section order and created
  this log. Prior AGENTS.md content (skill pointers, archinstall field notes) was preserved.

- 2026-11-03T08:57Z [USER] Supplied monotonic journal line:
  `[  415.378081] LuicipherOS kernel: amdgpu 0000:03:00.0: enabling device (0006 -> 0007)`.
  First matching device message is about 6 min 55 s after kernel start. This is not a
  completed-initialization timestamp; the earlier error-check result remains unreported.

- 2026-11-03T08:54Z [USER] Supplied kernel command line includes `amdgpu.runpm=0
  modprobe.blacklist=amdgpu systemd.mask=amdgpu-late.service 3`.

- 2026-11-03T08:50Z [ASSUMPTION] Earlier-session summary in this conversation records a blank
  Nov 1 power-on and a normal Nov 2 power-on. The assistant's existing issue #11 comment
  describes hard power-off recovery for Nov 1. These historical details were carried forward
  from that summary, not newly re-tested in this session.

- 2026-11-03T08:50Z [USER] Screenshot: saved boot -1 starts Nov 2 at 12:49:22 CET and ends
  at 23:01:28 CET; current boot starts Nov 3 at 09:40:22 CET. `uptime -s` reports
  2026-11-03 09:37:48 local time (08:37:48Z). No separate boot for the failed attempt is
  visible in the supplied list. Journal timestamps alone do not establish clean shutdown.

- 2026-11-03T08:50Z [TOOL] An update comment was posted to issue #11:
  https://github.com/lui-do/LuicipherOS/issues/11#issuecomment-6599309547 .

- 2026-11-03T08:49Z [USER] User reported being on the desktop.

- 2026-11-03T08:41Z [USER] Morning power-on showed a black screen with nothing appearing.
  After another power-off/power-on the boot options appeared and the user chose the default
  entry. Exact time of the failed attempt is UNCONFIRMED.

- 2026-10-31T13:48Z [TOOL] Issue #11 created for the boot/GPU problem and follow-ups.

- 2026-10-31T12:35Z [USER] Cold boot to `linux-lts` with `nomodeset` worked (low-resolution
  firmware framebuffer).

- 2026-10-31T10:51Z [USER] `systemctl reboot` from the 7.2.8 session: no video, no ASUS logo,
  Caps Lock dead; hard power-off needed. Details in [DISCOVERIES].

- 2026-10-31T10:42Z [USER] Desktop: `pacman -Syu` (176 packages incl. hyprland 0.57.0,
  linux 7.2.11, linux-lts 6.18.59, systemd 262.1) wrapped by snap-pac pre/post snapshots
  #2/#3. `bootctl update` run; no `.pacnew`/`.pacsave` files. Reboot result: see below.

- 2026-10-31T10:30Z [USER] Desktop: Snapper root config created; `/.snapshots` remounted from
  `@snapshots` (subvolid 260); snapper-timeline and snapper-cleanup timers active; baseline
  snapshot #1 "baseline before lui sync". Changes are on the machine, not yet in repo lists.

- 2026-10-31T10:07Z [TOOL] AGENTS.md rewritten to the 11-section template; this file created.
  Existing archinstall field notes and agent-skill pointers were preserved.

- 2026-10-06T15:32Z [CODE] Added the DMUB cold-boot case file and upstream draft; added the
  ReBAR check that trusts a mapped 32G BAR over sysfs node presence. Commit `3fa024d`.

- 2026-10-06T14:05Z [CODE] Added `install/amdgpu-late.service` and wired it into `bootstrap.sh`
  with an AMD vendor-ID gate. Commit `da245f2`.

- 2026-10-06T13:32Z [CODE] DMUB cold-boot case file added for external research. Last commit
  before this entry: `d53f205`.

- 2026-10-06T12:05Z [CODE] ReBAR check trusts the mapped 32G BAR over sysfs node presence.

- 2026-10-04T14:27Z [CODE] Installer skips connection setup when already online (closes #6);
  commented-out mirrorlists healed proactively (closes #7).

- 2026-10-04T10:33Z [CODE] Switched to Czech QWERTY defaults and number-row workspace binds.

- 2026-10-04T08:33Z [CODE] Target hardware manifest added: TUF B650E-PLUS WIFI, 32G Apacer,
  1TB Kingston, RX 7900 XT.

- 2026-10-03T20:06Z [CODE] ISO re-verified on fresh Oct-02 artifact: all green incl. portal picker.

- 2026-10-02T21:11Z [CODE] Split flatpak scopes and generalized `sync.sh` prune attribution.

- 2026-09-28T01:23Z [CODE] ISO-loop smoke PASS: netinstall image -> live boot ->
  `luicipheros-install` -> archinstall -> bootstrap -> desktop, five checkpoints green.

- 2026-09-28T00:00Z [CODE] ISO-loop PASS (own netinstall image -> archinstall 2m19s -> desktop).

- 2026-09-26T14:59Z [CODE] VM smoke PASS on the 2026.09.01 ISO after fixing the archinstall
  schema, multilib, repository-dead packages, yay bootstrap, and protected boot-chain packages.

- 2026-09-26T00:00Z [CODE] VM smoke PASS (QEMU/OVMF, 2026.09.01 ISO), five checkpoints green.

## [DISCOVERIES]
- 2026-11-19T23:40Z `[TOOL]` **Blank-display fault characterised; corrected an earlier misreading of
  the journal clocks.** Mechanism: the kernel writes its console into the framebuffer the firmware
  left behind, but the GPU is not scanning it out, so nothing is displayed while the machine runs
  normally. Nothing re-initialises the display until `amdgpu` loads at ~176-208 s (soft-blacklisted
  for the DMUB workaround) - hence a ~3-minute dark window on a bad boot, with the picture appearing
  when the driver loads. **Correction: `simpledrm` is NOT late.** It is built-in
  (`CONFIG_DRM_SIMPLEDRM=y`, `CONFIG_SYSFB_SIMPLEFB=y`, `CONFIG_FB_EFI=y`) and its console switch
  happens ms after the kernel's first line; the 24-56 s figures were a monotonic-clock offset equal
  to pre-kernel boot time (firmware POST + bootloader loading a 53 MB initramfs). Evidence: within
  boot -1 wall (21:32:12->21:39:14 = 422 s) and monotonic (37.894->459.697 = 421.8 s) agree, yet
  systemd's first line lands 33 ms after the kernel's first line - impossible for real time. Also
  noted: the motherboard-HDMI test was inconclusive (iGPU has no driver until amdgpu loads, and
  firmware drives the primary/discrete card). All four recent boots report **0 DMUB/power-gate
  errors**, but all used the late load, so the decisive display experiment is a boot with the driver
  NOT blacklisted (early load) - if that is also DMUB-clean the late-load pair could be retired and
  the display would come up immediately; boot-critical, needs explicit approval, revert = restore
  the blacklist and re-enable the unit. Docs updated: docs/warm-reboot-post-hang.md (Mode B +
  correction + open question), docs/warm-reboot-action-plan.md, AGENTS.md.
- 2026-11-19T23:00Z `[TOOL]` **CLOSED: `efi` reboot also succeeds -> the mechanism is not the
  variable; the fix was clearing the BIOS NVRAM.** User set `/sys/kernel/reboot/type` to `efi` and
  rebooted: clean (boot -1 21:32:12-21:39:14 -> boot 0 21:40:11, 3/3 for the day, all with amdgpu
  loaded). The SoC still reports `0x00080800` (CF9 write) for the efi path too, i.e. this firmware's
  ResetSystem() also ends in a CF9 write - the platform reset path is uniform, which is exactly why
  no `reboot=` experiment ever changed anything. Only distinct reason codes ever seen on this
  machine: 0x00080800 (4x, all completed resets) and 0x00200800 (7x, all power-ons). Conclusion: the
  fault was in **non-visible NVRAM state** (the optimised-defaults export differs from the
  pre-failure baseline only in Fast Boot and Integrated Graphics, so no visible setting was to
  blame), cleared by Load Optimized Defaults + Fast Boot Disabled. **Root cause UNCONFIRMED;
  regression possible** - documented remedy card (F5 defaults -> Fast Boot Disabled -> F10, profile
  `docs/bios-profiles/DISABLEDFASTBOOT_CMO.CMO`), fallback `rtcwake -m off -s 60`, prep list (copy
  the CMO to a FAT32 USB now; do not churn BIOS settings; re-test one reboot after any BIOS change;
  Gen4/IOMMU levers cancelled). No hardware fault demonstrated -> **no RMA case for the POST hang**;
  issue #11's DMUB storm and the blank-display fault remain open and separate. AGENTS.md boot-state
  paragraph and issue-#11 status rewritten; docs/warm-reboot-post-hang.md carries the conclusion,
  docs/warm-reboot-action-plan.md the remedy + prep.
- 2026-11-19T22:30Z `[TOOL]` **Second successful OS warm reboot: 2/2, both CF9/ACPI.** Boot -1
  (21:12:29-21:31:10) -> boot 0 (21:32:12), a 62 s cycle, again `systemd-logind: The system will
  reboot now!` and again reason `0x00080800` (CF9 write); `/sys/kernel/reboot/type` = acpi. amdgpu
  was loaded in both successful boots (176 s and 208 s), so the GPU being initialised is not what
  breaks it - the 'what the OS leaves behind' theory is not doing the work. **Path equivalence
  checked: `/usr/bin/reboot` is a symlink to `systemctl`, so `sudo reboot` and the Vicinae button
  are the same path (systemctl -> logind -> reboot(2)) - the tool is not a variable, the machine
  state is.** Standing conclusion: the configuration now reboots reliably 2/2; remaining question is
  whether the fix was the NVRAM reset (optimised defaults) or the mechanism, which experiment B
  (`echo efi > /sys/kernel/reboot/type` then reboot) settles. Docs: docs/warm-reboot-post-hang.md
  (reproducibility table), docs/warm-reboot-action-plan.md.
- 2026-11-19T22:00Z `[TOOL]` **BREAKTHROUGH: the first OS-initiated warm reboot ever completed POST
  - and the AMD reset-reason code names the mechanism.** `sudo reboot` via logind (Vicinae) from
  boot -1 posted: Q-LEDs amber->red->white->green, TUF splash, boot menu, LUKS prompt. The next boot
  reports `Previous system reset reason [0x00080800]: software wrote 0x6 to reset control register
  0xCF9` - i.e. the **ACPI FADT hard reset (CF9)**; `/sys/kernel/reboot/type` = `acpi`. Every reset
  this board has ever completed is a CF9 write (boot -3 = firmware save&reset after defaults, boot
  -1 = firmware save&reset after Fast Boot off, boot 0 = the OS reboot); the other reason code seen,
  0x00200800, just means 'came from a power-on'. **Methodological key: a hung reset is followed by a
  power cycle, and the power-on overwrites the reason code - so failed mechanisms are invisible,
  which is why reboot=c/t/e all looked like the same failure.** Confirmed from the journal: the
  reboot was `systemd-logind: The system will reboot now!`, and amdgpu had loaded at 176.9s in boot
  -1, so the GPU was initialised and it still worked. Consequences: (a) stale NVRAM is a live
  suspect (defaults were loaded immediately before the first working reset), (b) the mechanism
  question is reopened. Next two experiments: A) `sudo reboot` 2-3x for reproducibility (a single
  success misled once already on 2026-11-16); B) `echo efi > /sys/kernel/reboot/type` then reboot -
  if efi hangs, EFI ResetSystem is the broken path and the fix is `reboot=a` in the boot entry; if
  it works, the NVRAM reset was the fix. Separately, the blank-display fault is now diagnosed: the
  LUKS-prompt console comes from the firmware framebuffer and `simpledrm` initialises very late (24s
  / 56s / 161s across three boots), amdgpu being blacklisted until ~176-208s; the motherboard-HDMI
  test was inconclusive because the iGPU only gets a driver once amdgpu loads and firmware drives
  the primary (discrete) card. Live BIOS state = DISABLEDFASTBOOT profile. Docs:
  docs/warm-reboot-post-hang.md (Breakthrough section), docs/warm-reboot-action-plan.md (Step 2
  result + experiments A/B), docs/bios-profiles/README.md.
- 2026-11-18T20:40Z `[TOOL]` **Corrected: the blue LED is the case POWER LED, so rtcwake -s 20
  genuinely failed and the widened hypothesis is withdrawn.** User clarification: the LED they
  watched is the blue power light that shows whether the desktop is powered, independent of Linux -
  not the green BOOT Q-LED. Power LED off means the board was never powered, so the alarm was missed
  (20 s can elapse while the kernel is still shutting down). Withdrawn: 'a power-on can fail to
  POST' - that reading came from misidentifying the LED, and there is no evidence for it. Use
  `rtcwake -m off -s 60` (confirmed working); verify a wake by the blue power LED first, then the
  Q-LEDs. Separately sharpened Mode B (blank display): `journalctl --list-boots` shows **no Linux
  boot at all** in that window, so the machine was sitting in firmware (most likely BIOS setup, Del
  had been pressed) - Mode B is a **firmware display-initialisation failure (GOP/VBIOS), not amdgpu
  and not the OS**, reproducible with no Linux running. Test: other GPU output (DP vs HDMI),
  motherboard video output (iGPU now Auto), monitor-only power cycle; and record whether the monitor
  says 'no signal'. Rewrote docs/warm-reboot-action-plan.md as a clean ordered runbook: Step 0 entry
  cleanup, Step 1 Fast Boot -> Disabled (keep iGPU Auto), Step 2 the warm-reboot test still
  outstanding, Step 3 display-output test, Step 4 rtcwake confirm at -s 60, Step 5 BIOS re-flash
  (needs approval), Step 6 warranty, plus a record sheet.
- 2026-11-18T20:00Z `[TOOL]` **rtcwake -s 20 timeline reconstructed; possible
  power-on-without-POST.** From `journalctl --list-boots` (CET): boots -2 23:09:15-23:14:08, -1
  23:16:07-23:25:18, 0 23:35:57-. The `-s 60` success fits the 1m59s -2 -> -1 gap. The `-s 20`
  attempt is the shutdown at 23:25:18 and the next Linux boot is 10m39s later (23:35:57), that gap
  being the BIOS/defaults session (export header 22:33 UTC = 23:33 CET). **No Linux boot exists near
  23:25:38**, when the alarm would have fired. User reports the green BOOT Q-LED never lit - green
  is the fourth Q-LED, so firmware never reached boot-device scan. Reading: either the alarm never
  woke the board, or it powered the board **without running POST** (same Mode A as the warm-reset
  hang). `-s 20` is the prime suspect for the former (alarm can fire mid-shutdown and be
  cleared/ignored). If the latter, a power-on can fail to POST too - widening the fault beyond
  resets and weakening 'cold boot always works' further. Note boot entries only exist for boots that
  reached Linux, so a power-on that never booted is invisible in the list. Decisive test recorded:
  `rtcwake -m off -s 60`, then watch Q-LEDs / fans / power LED for 3 min without touching anything.
  Docs: docs/warm-reboot-post-hang.md (timeline + widened hypothesis),
  docs/warm-reboot-action-plan.md.
- 2026-11-18T19:10Z `[TOOL]` **Mode B found: blank screen with Caps Lock ALIVE - a second, different
  fault. Plus optimised defaults loaded (only Fast Boot and iGPU changed).** Sequence: `rtcwake -s
  20` did not visibly return; the next power-on gave no display **but Caps Lock responded**; the
  following power-on showed BIOS normally. Caps Lock responding proves the machine was running, so
  this is NOT the warm-reset POST hang (Mode A: no Q-LED, Caps Lock dead) - it is the issue #11
  blank-start family, an intermittent display bring-up. Open reading: rtcwake may have actually
  woken the machine into a displayless boot, making the two observations one event. Rule adopted:
  judge a wake by fans/power LED, never the screen, and wait 3 min before touching anything. rtcwake
  timing: -s 60 works, -s 20 unproven - use 60 until settled. Also corrected: `Power On By RTC` is
  Disabled in BOTH the baseline and the defaults export, yet the RTC wake worked, so it is not the
  gate (an earlier note here said it was). Optimised defaults
  (`docs/bios-profiles/OPTIMISEDDEFAULTS_*`) differ from BEFOREMCR only in `Fast Boot` Disabled ->
  Enabled (restore to Disabled: it skips POST stages and shortens the Del window) and `Integrated
  Graphics` Disabled -> Auto (can stay Auto as a free second display output for diagnosis); MCR
  reverted to Auto, harmless. **The Step 2 warm-reboot test has still not been run.** Docs:
  docs/warm-reboot-post-hang.md (two-failure-mode table), docs/warm-reboot-action-plan.md (Step 2
  result + rtcwake re-test), docs/bios-profiles/README.md.
- 2026-11-18T18:20Z `[TOOL]` **Step 1 done: recovery practised and `rtcwake` RTC wake verified
  working.** The machine shut down and powered itself back on to the boot menu, so a one-command
  restart now exists that uses the only condition this board handles reliably (clean ACPI S5, rails
  collapsed). Recommended delay is `-s 20` (15-20 s floor; the RTC alarm must not fire mid-shutdown
  or it can be missed and the machine stays off - 60 s was needlessly generous). This removes the
  daily pain regardless of the underlying fault, and is the candidate for a future `lui cold-reboot`
  subcommand. Docs updated: docs/warm-reboot-action-plan.md (Step 1 result + tighter delay),
  docs/warm-reboot-post-hang.md (workaround marked verified). Next: Step 0 entry cleanup then Step 2
  (Load Optimized Defaults + one reboot check).
- 2026-11-18T17:30Z `[TOOL]` **Ordered runbook written for the next hands-on session:**
  `docs/warm-reboot-action-plan.md` (recovery card, Step 0 entry cleanup, Step 1 recovery practice +
  `rtcwake` one-command restart, Step 2 BIOS 'Load Optimized Defaults' as a stale-NVRAM test with
  one reboot check, Step 3 BIOS re-flash 4004 or downgrade 3881 requiring explicit approval, Step 4
  warranty wording, plus the already-ruled-out table). Step 1 exists because on 2026-11-18 a forced
  button-off was followed by one dead power-on before the next worked - the recovery has to be
  practised twice so a failed first power-on is recognised as normal, and so every later result
  stays attributable. 'Load Optimized Defaults' (F5/F10 in setup) replaces the physical CMOS clear
  for Step 2: no case opening, and since saving in setup also resets the platform it doubles as a
  firmware-driven reset test. Findings doc now points at the runbook.
- 2026-11-18T16:40Z `[TOOL]` **Fans spinning during the dead state -> board is powered but never
  starts POST: EC sequencing latch, not a supply fault.** With `pci` (CF9) selected: no observable
  reset, no Q-LED, no splash, no boot; then the first power-on after the forced off also showed
  nothing and only the second reached the boot menu. Fans ran the whole time, so the PSU is
  delivering (12 V present) - the platform simply never begins POST. Reading: the EC's
  power-sequencing state machine sticks after a reset and only clears when the rails fully collapse
  (clean ACPI S5 has never failed; AC removal clears it; a forced button-off is not equivalent
  because +5VSB stays alive). Demotes PSU-as-supply-fault, GPU, memory and boot device for this
  symptom; elevates EC firmware and therefore the beta BIOS 4004 / AGESA 1.3.0.1d. Also weaker
  bedrock: 'cold boot always works' is really 'cold boot works after enough rail discharge'. Order
  from here: strict recovery protocol (poweroff, else unplug + hold power 20-30 s), EC drain + CMOS
  clear as tests (settings restorable from docs/bios-profiles/), GPU-removal warm-reboot test, BIOS
  downgrade to 3881 or re-flash of 4004 (needs explicit approval), then motherboard RMA. Doc:
  docs/warm-reboot-post-hang.md.
- 2026-11-18T16:00Z `[TOOL]` **sysfs probe: `pci` is accepted and `pci` == BOOT_CF9_FORCE - the CF9
  test needs no entry edit.** Accepted names on kernel 7.3.4: acpi kbd bios triple pci efi;
  rejected: cf9, cf9_safe (so this build uses the command-line spellings, not the `cf9_force` name
  in the ABI doc). Writing `pci` therefore selects the CF9 hard reset - exactly the mechanism
  firmware most plausibly uses when leaving setup - and can be exercised with `echo pci >
  /sys/kernel/reboot/type; reboot`. Remember the kernel falls back to KBD then triple if the
  selected port does not reset. Test order from here: pci (CF9), then acpi, then stop - the
  mechanism branch is then complete. Doc: docs/warm-reboot-post-hang.md.
- 2026-11-18T15:40Z `[TOOL]` **Default reboot type is `efi` - every failure has used UEFI
  ResetSystem() - and the sysfs knob rejects cf9_force.** `/sys/kernel/reboot/type` prints `efi`, so
  `reboot=e` repeated the default instead of varying it, and the warm-reboot hang has never once
  been tested with a non-EFI mechanism. The firmware's own setup-exit reset (the only warm reset
  that POSTed) is therefore *not* the EFI runtime path. Writing `cf9_force` returned EINVAL on
  kernel 7.3.4, so CF9 must go through the command line (`reboot=p` = BOOT_CF9_FORCE) - the sysfs
  accepted-name set for this build still needs probing (acpi/kbd/pci/cf9). Plan: probe the knob with
  `acpi` (zero setup; if accepted, it is a genuinely untested mechanism and on AMD the FADT reset
  register is often a chipset/PCI-based hard reset, i.e. close to the firmware path), then fall back
  to `reboot=p` in the entry. Watch the failure signature on CF9: if the machine does not reset at
  all, the port is unimplemented there - a different signature from a dead POST. Doc:
  docs/warm-reboot-post-hang.md.
- 2026-11-18T15:00Z `[TOOL]` **reboot=e (EFI ResetSystem) also hangs; switched the mechanism tests
  to /sys/kernel/reboot/type.** Verified from arch/x86/kernel/reboot.c that `e` is a real letter
  (BOOT_EFI = 'e', `efi.reset_system`) and that `p` = BOOT_CF9_FORCE, i.e. a write to the chipset
  CF9 hard-reset port - which is very likely what AMI firmware uses when exiting setup, making
  `reboot=p` the top remaining candidate. Linux >= 5.11 exposes the same knob at runtime as
  `/sys/kernel/reboot/type` (valid: bios acpi kbd triple efi cf9_force cf9_safe), which removes the
  entry-edit + cold-boot + verify cycle that produced two false negatives, and also reports what the
  machine currently uses. Also noted: the host BIOS setup offers only 'Save/Discard Changes and
  Exit' (no explicit Reset item); on AMI firmware exiting setup does issue a platform reset, but the
  2026-11-18 firmware-reset success is only confirmed retrospectively if the ASUS splash/POST was
  seen again. Doc: docs/warm-reboot-post-hang.md.
- 2026-11-18T14:00Z `[TOOL]` **First warm reset that ever POSTed: firmware-driven reset works -> the
  OS's reset never reaches the EC. Also a self-correction.** Procedure: power off -> Del into setup
  -> 'Discard Changes and Exit' -> boot menu appeared normally, no OS running at reset time. Single
  observation, two caveats: repeat with the explicit *Reset* item and time it (an instant menu means
  no reset happened). This invalidates the earlier 'reset mechanism does not matter' conclusion:
  `reboot=c` only sets a cold/warm *mode* hint that x86 largely ignores (the type stayed default),
  and `reboot=t` (triple fault) resets the CPU only and never signals the EC - which explains the
  dark Q-LEDs. So no OS reset *mechanism* was ever actually varied. Live hypothesis: ACPI/default
  reset is not delivered to the EC as a real platform reset on this board (beta AGESA 1.3.0.1d),
  while firmware's own reset is. Untried x86 types: `reboot=e` (EFI ResetSystem - closest analogue,
  shippable one-liner if it works), `reboot=p` (PCI), `reboot=a` (forced ACPI), `reboot=b`,
  `reboot=k`. Method: edit options in place (never append again - that trap caused two false
  negatives), cold boot, verify /proc/cmdline, reboot, then validate via `journalctl -k -b -1 | grep
  'Kernel command line'`. Hardware plan demoted but kept (EC drain, GPU-out, PSU identification).
  Doc: docs/warm-reboot-post-hang.md.
- 2026-11-18T13:10Z `[TOOL]` **Decisive: no Q-LED at all during the warm-reboot hang -> board never
  enters POST, GPU demoted.** User reports that on every warm reboot no Q-LED lights or blinks; on a
  healthy boot the sequence is red (CPU) -> white (VGA) -> green (BOOT, lingers while scanning boot
  devices, then logo+menu appear instantly) - manual confirms colours CPU/DRAM/VGA/BOOT =
  red/yellow/white/yellow-green. Dark LEDs mean the board dies before the CPU stage, so the GPU,
  memory training, boot-device enumeration and every loader/OS-side cause are out of this chain (the
  DMUB cold-boot storm remains a separate OS-side issue). Failure is power-on sequencing: EC state
  after reset, PWR_OK, +5VSB, or PSU protection/latch. Also trivialises the black screen and dead
  Caps Lock. Open splitter: are fans spinning / is standby power alive during the hang -> rails
  present = EC/firmware; rails gone = PSU/5VSB. **BIOS update lever is closed:** ASUS lists 4004
  (2026-09-21, AGESA 1.3.0.1d) as newest AND it is beta - the machine already runs the latest
  firmware; 3xxx builds carry anti-rollback restrictions. Next tests, in order: firmware-initiated
  reset (Esc/F10 in BIOS setup - does the EC reset path hang with no OS at all?), rail/standby
  observation, EC power-drain, boot with the discrete GPU removed (iGPU only - decisive for RMA
  targeting), PSU identification (label photo; still UNKNOWN since October) and swap. Warranty
  target pivots from GPU to motherboard/PSU. Doc updated: docs/warm-reboot-post-hang.md.
- 2026-11-18T12:00Z `[TOOL]` **reboot=t (triple fault) reproduced the hang - software ladder closed
  and validated.** The 2026-11-18 test was checked against the trap that produced two earlier false
  negatives: `journalctl -k -b -1` for the boot that performed the reboot (11:05:05-11:09:55) shows
  `... amdgpu.runpm=0 reboot=t` in its Kernel command line, and the only `Unknown kernel command
  line parameters` entry is `cryptdevice=...` (benign - the initramfs `encrypt` hook reads it from
  /proc/cmdline; the kernel proper does not consume it). So the parameter was applied, and POST
  still failed: reset *mechanism* is irrelevant (ACPI/KBC cold reset, default reset, triple fault
  all hang; power cycle always works). Software side is now fully exhausted across reset type, boot
  entry, unload unit, and reset params. Next evidence is the board's Q-LED during a hung POST (VGA
  vs DRAM vs CPU vs BOOT) - free, and the single fact that separates a GPU-state theory from memory
  training or board/CPU. Hardware ladder, cheapest first: EC power-drain (safe now - BIOS profiles
  exported in docs/bios-profiles/), PCIEX16(G5) Link Mode -> Gen4, IOMMU -> Disabled, then a BIOS
  update (needs explicit approval). Workaround offered: `sudo rtcwake -m off -s 60` = real S5
  poweroff + RTC wake, i.e. a scriptable cold boot; gate is APM -> Power On By RTC (baseline ErP
  Disabled keeps it usable). Doc updated: docs/warm-reboot-post-hang.md (validation section + Q-LED
  observation table + hardware plan).
- 2026-11-16T23:22Z `[TOOL]` **Warm-reboot POST hang isolated on the host; software side
  exhausted.** Verified from ESP dumps: all non-LTS entries share the *same* `initramfs-linux.img`
  (built 2026-11-15 13:55:20, contains `hooks/encrypt` + `usr/bin/cryptsetup`) and byte-identical
  root params (`cryptdevice=PARTUUID=3eea...:root root=/dev/mapper/root ...`); `HOOKS` uses the
  busybox `encrypt` hook, so `cryptdevice=` is correct. Therefore the 2026-11-16 LUKS panics (`VFS:
  Cannot open root device /dev/mapper/root`, error -19) were NOT a hook mismatch and NOT a broken
  initramfs - the only differing params were the Phase-2 experiment set, and `iommu=soft` (the sole
  early-userspace-affecting one) is the remaining suspect; it is dropped. Warm-reboot tests
  2026-11-17: hangs from the **archinstall entry** as well (not just the custom one), and hangs
  **with `amdgpu-unload-on-shutdown` disabled** too -> both the boot entry and the unload unit are
  exonerated; reboot=c and MCR-off were already negative. Everything on the software shutdown path
  is now cleared. Next single variable: `reboot=t` (triple fault) - a reset *kind* change, not a
  tweak: boot it, verify `/proc/cmdline`, then reboot. If it boots, reset signalling is the fault
  (shippable param); if it hangs, POST cannot complete after any non-power-cycle (GPU/EC/PSU state)
  -> BIOS levers (PCIEX16(G5) -> Gen4, IOMMU -> Disabled, ASUS EC reset) and a warranty position.
  State now: default entry = archinstall `2026-10-04_17-11-07_linux.conf`, `arch-lateload.conf`
  unused/do-not-boot (panics), unload unit disabled pending decision. Findings in
  `docs/warm-reboot-post-hang.md`. **User deferred the reboot=t test to 2026-11-18 and asked for no
  config edits on 2026-11-17.**
- 2026-11-15T22:51Z `[TOOL]` Warm-reboot test #2 (MCR=Disabled + unload unit enabled): **still hangs
  POST** — no logo, no menu, no keyboard power. Two takeaways. (1) Instrumentation flaw: the
  `logger` receipts never appeared because at that shutdown stage the journald socket is already
  dead — absence of the receipt proves nothing either way; receipts must go to `/dev/kmsg` instead
  (kmsg is relayed into the journal by PID1 through the whole shutdown). (2) The negative result is
  still informative even with that uncertainty: MCR-off alone did not fix it, so memory-training
  restore is NOT the trigger. Leading suspect now: the EC/PCIe warm-reset path itself. Next single
  variable (user-runnable, one sed): `reboot=c` kernel param — asks the reset path to treat the next
  boot as COLD via the keyboard-controller 0xFE interface; if it works, it doubles as the shipped
  fix (bootstrap + docs). Then queue: unit v3 (kmsg receipts + unload + PCIe Secondary Bus Reset of
  the GPU bridge at shutdown), then BIOS PCIEX16(G5) Link Mode -> Gen4. If reboot=c AND SBR both
  fail, firmware-side warm reset is defective -> warranty signal: 'soft reset never completes POST,
  power cycle required' is testable in any service center in 30 s.
- 2026-11-15T22:39Z `[USER]` **MCR experiment in place; BIOS exported profiles captured as
  evidence** (`docs/bios-profiles/`). The BEFORE/AFTER `setting.txt` diff proves **exactly one real
  change**: `Memory Context Restore Auto -> Disabled` (plus the USB stick appearing in the boot
  list). Baseline read from the export - whole board is factory-Auto: Launch CSM **Disabled**, Fast
  Boot Disabled, Ai Overclock Tuner Auto (EXPO off), Curve Optimizer Auto, Power Supply Idle Control
  Auto, Global C-states Auto, Above 4G Decoding Enabled (MMIO 40bit), ErP Disabled, cTDP105 off,
  TSME Auto, Power Down Enable Auto. **New suspect identified from the export: `PCIEX16(G5) Link
  Mode [Auto]` on a Gen5-capable slot** - if MCR-off doesn't fix warm reboot, next single variable
  is forcing that link to **Gen4** (the 7900 XT is a Gen4 device anyway), then CSM as lever #3.
  NOTE: the instrumented unload unit is NOT yet installed in /etc (still silent v1) - must reinstall
  before the next warm-reboot test or it is inconclusive again.
- 2026-11-15T14:25Z `[TOOL]` Unload-on-shutdown test was **inconclusive, not failed**: the unit
  logged nothing, so there is no proof `modprobe -r` executed before the hung warm reboot. Unit
  instrumented with journal receipts (`logger -t amdgpu-unload` on start/OK/still-in-use). Community
  corroboration found: warm/cold boot no-POST with black screen on AM5 is a well-documented
  **memory-training / Memory Context Restore (MCR)** family (multiple threads; reporters run Windows
  - further evidence this is not Arch's doing). Board currently has MCR=Auto. Next single-variable
  experiment: BIOS `Memory Context Restore -> Disabled`, then re-test warm reboot and read the
  receipts via `journalctl -b -1 | grep amdgpu-unload`. Standing workaround meanwhile: poweroff +
  power button (cold boot never fails).
- 2026-11-15T13:43Z `[USER]` Blank-start scope is wider than assumed: on the last reboot the monitor
  was black **from POST** (no ASUS logo, no systemd-boot menu), not only at LUKS. Pattern across
  incidents: sometimes all-visible, sometimes black at LUKS only, sometimes black from power-on yet
  the machine boots fine (Caps Lock alive, F8 menu appeared on a later attempt unprompted).
  Consistent with the 7900 XT UEFI GOP over HDMI being intermittently unsynced by the Philips
  monitor (link training / mode the panel rejects) rather than a firmware crash. Implications for
  the new automated boot: it is blind-safe (menu timeout 3 + default entry + timed amdgpu-late means
  NO visible output is needed until the login screen) but the procedure must be documented for a
  fully black boot: watch the keyboard LED to know POST finished, blind-type the LUKS passphrase
  ~35-45 s in, optionally power-cycle the monitor to force re-sync, expect login at ~3-4 min; if
  nothing by ~6 min, power-hold and retry (the symptom historically clears on a retry). Ordered DP
  cable remains the real cure for GOP/HDMI flakiness.
- 2026-11-15T10:07Z `[USER]` **New evidence, 2026-11-15: BIOS SETUP froze.** While checking
  settings after a clean reboot, the UEFI configuration utility itself locked up - no input
  did anything - and required a power-button hold. A freeze inside BIOS setup is bare
  metal/firmware with NO operating system, driver, MemTest86 or any software we control:
  it is the third independent bare-metal hang (MemTest86 resets 2026-11-13 and 11-14 plus
  this UEFI freeze) and further excludes software causes. The forced power-off explains
  this boot's `0x00200800` (ACPI transition), not a new CPU event.
  Voltages read in BIOS at the time (all within spec at idle): 12V=11.980 (-0.2%),
  5V=5.020, 3.3V=3.312, CPU core=1.296V, VDDIO/MC=1.12V, **SoC=1.040V** (down from
  1.272V with EXPO enabled - consistent with EXPO still off). Idle readings do not
  characterize sag under load. UNVERIFIED after the BIOS freeze+forced power cycle:
  whether Ai Overclock Tuner is still Auto (UEFI may restore defaults after a hard
  loss - defaults are EXPO-off anyway, but a glance next BIOS visit settles it).
- 2026-11-15T10:07Z `[TOOL]` ppfeaturemask VERIFIED ACTIVE: `/proc/cmdline` contains
  `amgpu.ppfeaturemask=0xffff7fff` (full value confirmed via `tr`), `/sys/module/amdgpu/parameters/
  ppfeaturemask` = 0xffff7fff (GFXOFF bit 0x8000 masked), zero gfxoff/DMUB lines this boot.
  Note: the checklist command given earlier (`grep -o 'amdgpu.ppfeaturemask=[0-9a-f]*'`)
  TRUNCATES at 'x' and falsely shows `=0` - use the `tr ' ' '\n' | grep -E 'amdgpu'` form.
- 2026-11-15T10:07Z `[USER]` Minor new symptom: while typing in the terminal (light load) the
  monitor briefly flashed to black and recovered by itself. Single occurrence so far; a transient
  link retrain/modeset event, most plausibly HDMI + the same flaky display path as the GOP black
  screen. To catch a repeat: `journalctl -k --since '-2 min' | grep -iE 'amdgpu|hdmi|display'` right
  after it happens.
- 2026-11-14T23:05Z `[TOOL]` **Operational trap: `git reset --hard` on a live stow tree trips
  Hyprland's config watcher.** While updating the deployed clone via `reset --hard` at
  2026-11-14 23:58, git briefly *removed and recreated* `hyprland.lua`; Hyprland's file
  watcher auto-reloaded inside that gap and latched a stale "cannot open hyprland.lua"
  banner. The file and config were healthy; one `hyprctl reload` cleared it. Rule going
  forward: when refreshing the deployed tree while the session runs, prefer plain `cp`
  (in-place writes), and after any `git reset/checkout` there, run `hyprctl reload` once
  to settle watchers. Documented in `docs/user-personalisation.md` (troubleshooting #1).
- 2026-11-14T22:01Z `[TOOL]` Read the Arch AMDGPU wiki Troubleshooting. Two sections are relevant:
  "System freezes or reboots when idle" (GFXOFF / PowerPlay driver crashes ->
  `amdgpu.ppfeaturemask`, conservative value `0xffff7fff`, stronger `0xfffd7fff` / `0xfffd3fff` /
  `0xfff73fff`) and "AMD dedicated GPU HDMI freezing issue on Wayland" (dGPU+HDMI; the
  `amdgpu.runpm=0` it recommends is already in the user's cmdline; its `DRI_PRIME` part is an
  iGPU/dGPU laptop case and does not apply to this iGPU-less desktop). Neither section addresses (a)
  the bare-metal `0x00800800` reset, which reproduces in MemTest86 with no amdgpu driver loaded, so
  no kernel param can touch it, or (b) the black-at-LUKS screen, which is on the card's UEFI
  firmware GOP framebuffer, before amdgpu loads. `amdgpu.ppfeaturemask=0xffff7fff` is therefore
  offered only for the *under-OS idle GPU freezes*, and is safe to add mid-EXPO-test because it
  affects only the Linux driver, never the bare-metal reset experiment. The black-at-LUKS remains
  best addressed by moving the monitor to a DisplayPort.
- 2026-11-14T22:01Z `[USER]` The "blank after reboot" is worse than the expected late-load state:
  the **LUKS prompt itself is black** - no text console either - every time, even at disk unlock.
  This is the #11 blank-start, and it now has a concrete mechanism.
- 2026-11-14T22:01Z `[TOOL]` Verified the early-display path. The **only** display device is the
  7900 XT (`03:00.0` Navi 31); there is **no iGPU**. The monitor is on **HDMI-A-1**. The early
  console (LUKS prompt and the runlevel-3 text console) is drawn on the card's **UEFI firmware GOP
  framebuffer** (`simpledrm`, low-res), which the kernel adopts before amdgpu is involved. amdgpu
  (the Linux driver) is blacklisted and not loaded until the user manually `modprobe`s it minutes
  later, at which point the card switches to a full-res mode and the monitor lights up. So the black
  screen is **not** the amdgpu driver and **not** the late-load workaround: it is the monitor
  failing to render the card's low-res UEFI GOP framebuffer over **HDMI** during early boot. The
  keyboard works (Caps Lock) because input is independent of the display; the system is alive and
  the user is typing into a screen the monitor is not showing.
- 2026-11-14T22:01Z `[TOOL]` Fixes, in order: (1) move the monitor to a **DisplayPort** - the card
  has DP-1/2/3 free, and AMD UEFI GOP frequently drives DP where HDMI shows nothing; (2) a
  **blind-boot** procedure (type LUKS passphrase + login blind, then `sudo modprobe amdgpu` + `sudo
  systemctl start greetd` - the display returns when amdgpu inits full-res); (3) check BIOS for a
  **CSM / UEFI GOP boot-display** toggle; (4) **defer** the firmware angle - the user is pinned at
  `20260916` with `20261019` in `[ignored]`, and the referenced Arch thread 314887 was specifically
  a firmware version causing "no video on HDMI", so the held-back version is a live lead for #11.
  Open questions: does the user have a DP cable / DP-capable monitor, and is the LUKS-time black new
  since the 7.3.4 kernel upgrade or the long-standing #11.
- 2026-11-14T21:30Z `[TOOL]` Full upgrade completed 2026-11-14 22:23 (`pacman -Syu`,
  snap-pac auto-snapshot). `linux` 7.2.11 -> **7.3.4**, `linux-lts` 6.18.59 -> **6.18.63**. The 2
  remaining
  "pending" packages are `linux-firmware` / `linux-firmware-amdgpu` at `[ignored]` - the deliberate
  `IgnorePkg` pin at 20260916, so they are **not** actually left behind. Running kernel is still
  7.2.11 until reboot. Boot entries confirmed before the upgrade: the user boots from the static
  hand-written `arch-lateload.conf` ("manual AMD GPU load"), which points at `/vmlinuz-linux` /
  `/initramfs-linux.img` by stable name, so the kernel swap does not drop the late-load params; the
  auto-managed `..._linux.conf` entry carries only `amdgpu.runpm=0` and must NOT be selected on the
  new kernel.
- 2026-11-14T21:30Z `[ASSUMPTION]` **Baseline now has two active changes at once:** EXPO
  off (DDR5-4800) AND kernel/mesa updated (7.3.4). For the hardware `0x00800800` reset this is fine
  (it
  reproduces bare-metal in MemTest86, so the kernel is irrelevant to it), but for the **display
  symptoms** (#11 blank start, #14 GPU D3hot wedge) the new amdgpu driver + mesa can no longer be
  separated from the EXPO-off change. The reset census should record which kernel each boot used.
- 2026-11-14T21:12Z `[USER]` **EXPO-off run, first clean extended result.** Setting `Ai Overclock
  Tuner` to `Auto` took the memory from `DDR5-6000 / CAS 38-48-48-96` to **`DDR5-4800 / CAS
  40-39-39-77`** (JEDEC default) and dropped `DRAM VDD` / `DRAM VDDQ` from `1.35 V` to `auto`. One
  continuous MemTest86+ session (reports 03 and 04 both back-calculate to a 17:21 start): **4 full
  passes in 3 h 39 m 58 s, zero errors, no reset**, then the user exited to the desktop, which is
  stable. (Passes are slower at 4800: ~55 min each vs ~22 min at 6000.)
- 2026-11-14T21:12Z `[ASSUMPTION]` **Promising but not yet conclusive.** The two EXPO-ON runs failed
  at ~40 min (during pass 2) and at 4 h 23 m. A clean 3 h 40 m therefore beats the fast failure but
  does not yet clear the slow one. Because the time-to-failure is variable, the decisive EXPO-off
  test is a **6-8 h clean MemTest86 run** (F6 before bed) plus **real-world monitoring** of the
  reset-reason register for 1-2 weeks. If both come back clean with EXPO off, EXPO / SoC-voltage /
  power-delivery is confirmed as the trigger. The voltage drop is coherent with a marginal PSU/VRM:
  EXPO was pushing DRAM to 1.35 V and SoC to ~1.27 V; removing that load could be what stops the
  reset.
- 2026-11-14T21:12Z `[TOOL]` **Do not toggle EXPO back on.** Keep `Ai Overclock Tuner = Auto` while
  the test runs. Cost is ~5% memory bandwidth (6000 -> 4800) and a little real-world performance;
  that is an acceptable, reversible trade while we confirm the cause. If the machine proves stable
  EXPO-off, the final decision (keep 4800 permanently vs. find the voltage headroom that lets 6000
  work) is a separate optimisation.
- 2026-11-14T17:08Z `[TOOL]` Checked the Arch "random freeze" thread (id 279589) the user
  found. It was
  actually solved as a **NIC PCIe AER fault** (`r8169` Uncorrected (Fatal), `device recovery
  failed` -> panic), fixed with `r8168-dkms`; the thread's general lesson is that AER errors can
  stem from **ASPM**. Applied to this machine: the wired NIC is a **Realtek RTL8125 2.5GbE
  (`0a:00.0`, driver `r8169`)**, and a full-boot scan for *true* AER/PCIe errors found **zero**
  (the 280 raw `pcieport` lines are all benign `PME: Signaling with IRQ` wake-ups), and zero errors
  on the NIC specifically. So the thread's cause is not present here. It does not explain the
  `0x00800800` MemTest86 reset anyway: that reproduces bare-metal (no `r8169`, no NIC traffic) and
  is a CPU-internal event, not a PCIe link error. What it does contribute is **ASPM** as a cheap
  BIOS toggle, recorded to fold into the EXPO-off test (do not change two things at once).
- 2026-11-14T17:08Z `[ASSUMPTION]` ASPM is now a plausible cause for the **Linux-side**
  PCIe power-state
  symptoms only (the blank start #11, the GPU D3hot wedge #14), not for the bare-metal MemTest86
  reset. Priority therefore: run the EXPO-off test first (the last clearable variable for the
  reset); ASPM is a secondary BIOS experiment for the display/GPU class of symptoms.
- 2026-11-14T16:53Z `[USER]` **BIOS baseline recorded** (first time these values have been read):
  `Ai Overclock Tuner` = **EXPO I** (enabled); `Memory Context Restore` = auto; `Precision Boost
  Overdrive` = **auto**; `Curve Optimizer` = **auto**; `Power Supply Idle Control` = auto;
  `CPU SoC voltage` = **1.272 V** (auto). **PBO and Curve Optimizer are therefore both ruled out** -
  the strongest earlier hypothesis for light-load instability was that an aggressive negative CO
  offset was set, and it is not set at all. VSOC at 1.272 V is inside AMD's ~1.30 V ceiling but on
  the high side for DDR5-6000; it is chosen by the board's auto rules *because EXPO is enabled*, so
  disabling EXPO should also lower it.
- 2026-11-14T16:53Z `[USER]` Another **hard lockup**, 2026-11-14 evening, while using Helium:
  animations (including text) **slowed progressively until the machine froze**, and then Caps Lock
  and Ctrl+Alt+Fn both did nothing, so the kernel was dead. A hard power-off was required. The
  progressive slowdown before death is a new detail - it suggests something **degrading under load**
  rather than an instantaneous fault. The previous boot ended at 17:01:43 with no clean-shutdown
  markers and no panic or lockup message in the journal, and the next boot reports `0x00080800:
  software wrote 0x6 to reset control register 0xCF9` - a different ending from the `0x00800800`
  events. That value is ambiguous: `panic=0`, `hardlockup_panic=0` and `softlockup_panic=0`, so the
  kernel would not self-reboot, and a four-second power-button hold does not reliably clear the
  register, so the CF9 reading may be stale.
- 2026-11-14T16:53Z `[ASSUMPTION]` **The failure rate is increasing.** The `0x00800800` resets ran
  roughly weekly (2026-10-19, 10-27, 11-05, 11-10), but 2026-11-12 to 11-14 produced, in three days:
  a hard lockup, a blank start (three attempts), a `0x00800800` reset and a second hard lockup. Some
  of that is explained by now running MemTest86 deliberately, but the 2026-11-14 evening lockup
  happened under ordinary Helium use. A rising failure rate on brand-new, shop-assembled hardware
  points at a **degrading or marginal component** and strengthens the case for warranty action
  rather than further software-side tuning.
- 2026-11-14T14:36Z `[USER]` **New symptom reported, distinct from the hard lockup: a blank start
  with the system alive.** On the morning of 2026-11-14, before the MemTest86 run, three attempts to
  boot Linux normally produced a **blank screen while Caps Lock still toggled its LED** - i.e. the
  kernel was running and processing input, and only the display had failed. F8 then displayed the
  firmware boot menu normally, and MemTest86 was selected from it. This is the "blank start" symptom
  already tracked in issue #11, and it is **not** the 2026-11-12 event, where Caps Lock did **not**
  toggle and the whole system was hung. Diagnostic value: a toggling Caps Lock separates a dead
  display from a dead kernel, and this event is the former.
- 2026-11-14T14:36Z `[TOOL]` Why those failed boots left no journal trace: `journalctl --list-boots`
  shows no boot between `d67af159` (ending 2026-11-13 23:50:27, a **clean** shutdown - `Reached
  target Shutdown`, `Unmounted /boot`) and `22ce242a` (2026-11-14 12:12:24). The persistent journal
  is only written after `/var/log` is mounted, which is after the LUKS unlock, so a boot whose
  screen is blank at the LUKS prompt can never be recorded. The blank screen therefore happens at or
  before the initramfs stage. On a working boot this session shows the sequence `simpledrm` ->
  `Console: switching to colour frame buffer device 128x48` (the text console, where the LUKS prompt
  appears), with `amdgpu` only initialising minutes later after the manual late-load. So the blank
  start is a **firmware-framebuffer / display handoff failure, before amdgpu is even loaded**, not
  an amdgpu driver failure.
- 2026-11-14T14:31Z `[USER]` **MemTest86 re-run produced a clean full pass AND a reproduction.**
  Report `MT86P_02.TXT`: `Passes completed: 1`, `Errors: 0`, `ECC Errors: 0`, `Final Result: PASS
  (running for 00:21:37)` - all twelve tests clean, including Test 03 (Bus stress, R/W turnaround)
  and Test 11 (Rowhammer). The machine then reset during pass 2, going straight to the LUKS prompt.
  Boot 0 (`22ce242a`, 2026-11-14 12:12:24) reports `0x00800800: internal CPU shutdown event
  occurred`, so this is the **sixth** event. A single pass takes **21 m 37 s**.
- 2026-11-14T14:31Z `[ASSUMPTION]` The fault is now **reproducible**: two MemTest86 runs, two
  resets, both with `0x00800800`. That converts an intermittent mystery into a test harness - a
  candidate fix can be evaluated in roughly an hour instead of waiting weeks. Time-to-failure varies
  widely (4 h 23 m on 2026-11-13 versus roughly 40 min this time), so it is load-dependent with a
  variable rate rather than a fixed soak, and any "clean" run must exceed ~4 h to be meaningful.
  **Memory is cleared** (one full pass clean, and the 2026-11-13 session ran long enough for roughly
  twelve passes at this pass time). Thermal is cleared. DIMM slots are cleared. What remains is
  **CPU / VRM / PSU**. Note MemTest86's own clock is unreliable (it reads a drifting RTC); boot
  times are authoritative.
- 2026-11-13T22:49Z `[USER]` Thermal test result: `Tctl` held **77-81 C** under a sustained all-core
  load (`yes` loop, all cores, 20-30 min). That is a plateau with a comfortable margin to the ~95 C
  throttle point, and on a 65 W 9600X with an ARCTIC Freezer 36 it is exactly what a healthy cooler
  produces. **CPU thermal is ruled out** as the cause of the load-induced resets. Caveats recorded:
  the `yes` loop is an ALU-only load (a heavier AVX workload could run warmer, but there is ~15 C of
  headroom); the test ran 20-30 min rather than the 4 h 23 m the fault took, though a flat plateau
  implies steady state; and **no motherboard/VRM temperature sensor is exposed** - `nct6775` is
  available but not loaded, and loading it on this board would need `acpi_enforce_resources=lax`,
  i.e. a boot-parameter change, so VRM temperature remains unmeasurable for now.
- 2026-11-13T22:49Z `[USER]` The `sudo pacman -Syu` was **declined at the confirmation prompt**
  (`n`), so no packages were installed and the diagnostic baseline is intact (linux 7.2.11, mesa
  26.2.6, systemd 262.1, running kernel 7.2.11). The package database is nevertheless **synced**,
  leaving 169 packages pending, including **linux 7.2.11 -> 7.3.4** and mesa 26.2.6 -> 26.2.7. The
  system is therefore in a partial-upgrade state: single-package installs are unsafe until a full
  `-Syu` is run, and that upgrade is deliberately **held** because a new kernel would destroy the
  baseline.
- 2026-11-13T14:36Z `[USER]` Verified on the board: the two DIMMs are in **DIMM_A2 and DIMM_B2**,
  which is the manual's recommended population for two modules. DIMM slot placement is therefore
  **ruled out**. This also means MemTest86's `Slot 1` / `Slot 3` labels are its own numbering
  (SPD-address order), not A1/B1 - do not read them as physical slot positions in future reports.
- 2026-11-13T12:41Z `[TOOL]` **Correction: there is no memory test result.** The F6 report the user
  saved (`MT86P_01.TXT`) ends with `Passes completed: 0`, `Errors: 0`, `Final Result: In progress
  (running for 00:00:07)`. It is a **seven-second snapshot** taken to prove F6 worked, not a
  completed pass. The earlier entry concluding "MemTest86 found zero errors" was based on the user's
  description and is **withdrawn**. Memory remains unmeasured at EXPO speed. The reset-under-load
  finding stands: the machine did reset at 04:10:42 during the session.
- 2026-11-13T12:41Z `[TOOL]` What the report does establish: `IMC: DDR5-6000 / CAS 38-48-48-96`, so
  **EXPO is enabled** (not JEDEC 4800); memory is `2 x 16384 MB DDR5-6000 Apacer GD2.5931WT.00J`
  reported in **Slots 1 and 3**. On AM5 the two-DIMM recommendation is normally A2/B2 (2nd and 4th),
  so the physical slot population needs verifying against the board manual - a known cause of
  instability at DDR5-6000. MemTest86's slot numbering may not map 1:1 to A1/B1, so this must be
  checked on the board, not inferred.
- 2026-11-13T12:41Z `[USER]` Hardware inventory (all components new): CPU cooler **ARCTIC Freezer 36
  Black**; PSU **Cooler Master "Elite Gold" 850 W**; RAM **Apacer PANTHER 32 GB DDR5-6000 CL38**
  (2x16, EXPO); case darkFlash Aquarius Mesh. 850 W is correctly sized for a 65 W 9600X plus a ~315
  W RX 7900 XT, so capacity is not the issue; the "Elite" tier is a budget line, and since
  everything is new a manufacturing defect is more plausible than wear. No spare PSU is available,
  so a PSU swap is not currently testable. `lm_sensors` **is installed** (`sensors` present);
  `s-tui`, `btop`, `nvtop` and `stress-ng` are available in the repos but not installed.
- 2026-11-13T12:27Z `[USER]` Correction to the load context of the earlier events.
  They were **not** at idle: the user was running Helium (Chromium) with 10-15 tabs plus
  a terminal with agents, i.e. real
  moderate-to-heavy load. Combined with the 2026-11-13 reset during 4 h 23 m of sustained MemTest86
  load, **every known event is load-induced**. This demotes **Curve Optimizer**, whose classic
  signature is instability at *idle and light load* (the CPU cannot hold the low idle voltage), and
  promotes **power delivery (PSU / motherboard VRM)**. It also means the 2026-11-13 event happened
  with the desktop already moved to the wall socket, so the power strip is not implicated in it.
  Thermal remains open and unmeasured: nothing has recorded CPU temperature under sustained load.
- 2026-11-13T12:19Z `[TOOL]` **The 2026-11-13 MemTest86 session gave the best evidence
  yet: the machine reset with `0x00800800` while MemTest86 was running, and
  MemTest86 reported zero errors.**
  Timeline (all verified): 2026-11-12 23:47:04 a clean `sudo reboot` by `luci` entered MemTest86
  (the journal shows a full shutdown sequence, `Unmounted /boot`,
  `The system will reboot now!`); MemTest86 ran
  **4 h 23 m**; at **2026-11-13 04:10:42** the machine reset - `btime` is 1794539442, and boot 0
  reports `Previous system reset reason [0x00800800]: internal CPU shutdown event occurred`. The
  machine then sat at the LUKS prompt until the user unlocked it around 10:44, which is why the
  persistent journal has no entries in the MemTest86 window (journald writes only after root is
  mounted).
- 2026-11-13T12:19Z `[ASSUMPTION]` This is the **fifth** `0x00800800` event (2026-10-19,
  2026-10-27, 2026-11-05, 2026-11-10, 2026-11-13) and the first under a known, controlled
  workload. The combination of
  **zero memory errors plus a CPU-level reset under sustained load** argues that the fault is **not
  memory data corruption**: the memory delivered correct data and the system died anyway. That
  demotes EXPO as a cause of data errors and promotes **power delivery (PSU/VRM) or CPU-level
  instability**. The ~4 h 23 m time-to-failure under sustained heavy load is the signature of
  something that degrades with heat or sustained power draw rather than a random bit flip.
- 2026-11-13T12:19Z `[TOOL]` Caveat on the memory result: the saved F6 report covers the
  **first pass only**, so it does not tell us how many passes completed in the 4 h 23 m
  A re-run would be
  valuable less as a memory test than as a **reproducibility test** - a second reset under the same
  conditions would convert an intermittent fault into a repeatable one.
- 2026-11-12T13:35Z `[TOOL]` Issue #13 rewritten so it is self-consistent: the Summary now lists
  both symptoms (instant resets and the 2026-11-12 lockup) as one likely CPU-level fault; the
  Evidence table uses the kernel's own reset-reason wording; "Ruled out" gains thermal, OOM/suspend
  and GPU; the test plan marks `modprobe amd64_edac` done-and-unavailable and keeps MemTest86 first.
  The earlier "partially superseded" banner was removed now that the body matches the comment.
- 2026-11-12T13:34Z `[TOOL]` `sudo modprobe amd64_edac` **failed**: `could not insert
  'amd64_edac': No such device`. The CPU is family 26 (0x1A, Zen 5 / Granite Ridge) and the
  module's aliases do include
  `cpu:type:x86,ven0002fam001Amod*:feature:*`, so it claims support, but init returns `ENODEV`
  and `/sys/devices/system/edac/mc/` stays empty. Even if it bound, this is consumer DDR5 without
  ECC, so there would be no correctable errors to count. EDAC is therefore a **dead end** as an
  early-warning system here. The kernel's MCE decoder is active (`MCE: In-kernel MCE decoding
  enabled`), so an uncorrectable machine check would still be logged; none has appeared in any
  retained boot.
- 2026-11-12T13:34Z `[TOOL]` Updated GitHub issue #13 at the user's request: retitled to "CPU-level
  events: instant resets (0x00800800) and hard lockups, cause unknown"; annotated the body as
  partially
  superseded; and added a comment with the corrected reset-reason decoding, the 2026-11-12 lockup
  evidence, the EDAC dead end, and the revised test plan (MemTest86 -> EXPO off -> PSU).
- 2026-11-12T13:19Z `[USER]` First-hand observation of the 2026-11-12 freeze, which settles its
  nature. The user was in Helium; the mouse cursor would not move; **Caps Lock did not toggle its
  LED**; the fans kept spinning; the monitor stayed on with a frozen image; and power-off required a
  **long press**.
  Caps Lock not toggling means the kernel was not processing input, and the fans still running means
  the machine was powered and not thermally shut down. This is a **hard kernel lockup**, not a dead
  display: the whole system stopped executing while power stayed on. A long press is a hardware cut,
  so no software shutdown occurred and nothing was flushed to disk.
- 2026-11-12T13:19Z `[TOOL]` **No memory-error visibility exists on this machine.** `amd64_edac` is
  built as a module (`CONFIG_EDAC_AMD64=m`, alias `fam001A` covers Zen 5 / Granite Ridge) but is
  **not loaded**, and `/sys/devices/system/edac/mc/` is empty, so no EDAC memory controller is
  registered and no
  correctable/uncorrectable counters exist. `dmidecode` is not installed, so DRAM speed and EXPO
  state cannot be read without root. A memory fault causing a hard lockup would therefore be
  completely invisible today.
- 2026-11-12T13:19Z `[ASSUMPTION]` Failure classes C and D are probably **one underlying
  CPU/memory/power fault with two outcomes**: `0x00800800` ("internal CPU shutdown event occurred")
  is the CPU-level event
  that resets, and the 2026-11-12 lockup is the same class of event that hangs instead. Both are
  CPU-level, both leave no useful trace, and both need a hardware cut or reset. This supersedes the
  earlier framing of `0x00800800` as memory-or-PSU, and it does not change the conclusion that the
  GPU D3hot wedge (class A) is a separate, understood problem.
- 2026-11-12T13:13Z `[TOOL]` Investigated the 2026-11-12 freeze. Boot `ef23e494` ran 13:39:12 to
  13:53:57 and its journal **stops mid-session** with no shutdown sequence, no suspend, no OOM
  kill, and no coredump. The kernel logged nothing at all after 13:40:44 (boot messages only), and
  userspace logged nothing after 13:53:57 except a scheduled tmpfiles job. No `Refused to change
  power state`, no DMUB/DMCUB error, no `gfxoff`, no `SMU: No response`, no vblank timeout: this is
  **not** the D3hot/DMUB wedge and **not** an OOM. The only kernel warning of note is
  `i2c-designware-pci 0000:03:00.3: timeout in disabling adapter` at boot, and Hyprland emitted ten
  `pixman_region32_*: Invalid rectangle passed` / `*** BUG ***` lines in the three seconds after
  start, which is startup noise, not a precursor three minutes later. No MCE, no hardware error and
  no thermal throttling appear in any retained boot, and temperatures are normal (GPU edge 47 C,
  junction 56 C, mem 70 C; Tctl 58 C). **The logs contain no explanation for the freeze.**
- 2026-11-12T13:13Z `[TOOL]` Reset-reason decoding corrected. The kernel strings are: `0x00200800` =
  "ACPI power state transition occurred" (22 boots, the normal case), `0x00080800` = "software wrote
  0x6 to reset control register 0xCF9" (3 boots, a software-initiated reset), and `0x00800800` =
  "**internal CPU shutdown event occurred**" (2 boots). The `0x00800800` class is therefore a
  CPU-level event, not a memory or PSU event as earlier assumed. Boot `db50dd3d` reports
  `0x00200800` for `ef23e494`'s end, which is the same value a clean poweroff produces, so it does
  not by itself prove the OS handled a power-button event.
- 2026-11-12T13:13Z `[ASSUMPTION]` The 2026-11-12 freeze is a **new, distinct failure class (D)**: a
  silent stop with no kernel trace, no reset-reason signature and no recovery path in the logs. It
  cannot be diagnosed from the journal. What is needed is the user's observation at the moment of
  the freeze.
- 2026-11-11T21:52Z `[TOOL]` Confirmed on the live machine. `lui status` as `luci` now prints
  `tree: /home/luci/LuicipherOS @ a86019d [home-fallback]` and reports 23 extras; as `work` it
  prints `tree: /home/work/LuicipherOS @ 1cc76c9 [home-fallback]` and reports 2. `a86019d` is the
  SIGPIPE-proof AMD-gate commit and predates `eb68366` (the 2026-11-02 inventory that declared the
  21 packages), which is exactly why the counts diverge. Two clones, two different answers to the
  same question, now visible instead of silent.
- 2026-11-11T21:48Z `[TOOL]` Near-miss that validates the multi-user concern. Running `lui` as the
  **admin account** `luci` resolved to `/home/luci/LuicipherOS` via the `$HOME/LuicipherOS`
  clone predates `eb68366` (2026-11-02, which declared the hand-installed packages), so `lui status`
  reported **23 pacman extras, 21 of which are declared** in the canonical tree. `lui sync --prune`
  run there would have removed 21 real packages. Two facts make this reachable rather than
  hypothetical: `/home/luci` is `drwx------` and `/home/work` is `drwxr-x---`, so `luci` **cannot
  read** the canonical tree at `/home/work/LuicipherOS` and the fallback is the only path available
  to that account. Fix: `lui sync`/`status` now always print `tree: <path> @ <sha> [<source>]`, and
  `--prune` from a `home-fallback` tree prints an explicit staleness warning (safe paths stay quiet,
  so the warning keeps its meaning). Covered by `tests/test_lui.sh` (16 checks).
- 2026-11-11T21:48Z `[ASSUMPTION]` Until a shared tree exists, reconcile from exactly ONE canonical
  tree, and never run `--prune` from a per-user clone. The per-user-clone model is not merely
  inconvenient; it is unsafe, because prune trusts the tree it is run from. This promotes the
  shared-tree item from a convenience to a correctness requirement.
- 2026-11-11T21:39Z `[TOOL]` Two file-mode traps found while adding the `lui` CLI.
  (1) `core.filemode=false` (set earlier in this clone to silence 160 phantom `.agents/skills/**`
  644->755 changes) also makes git **strip the executable bit on commit**, so `scripts/lui.sh`
  landed as 644 and the deployed clone could not run it. The real fix is not the config knob but
  restoring the worktree: 102 `.agents/**` files plus 57 other tracked files were wrongly `755` on
  disk while the index said `644`. `git ls-files -s | awk '$1=="100644"' | xargs chmod 644`
  cleared all of it, and `core.filemode` is now `true` again. New executable files must be staged
  with `git update-index --chmod=+x` if the bit is ever lost.
  (2) Never work around a mode problem with `core.filemode=false` in this repo; it silently
  breaks the next script added.

- 2026-11-11T20:55Z [TOOL] Shell-alternative evaluation for the
  "lots of customisability plus plugins" requirement. Facts: **Amane** is 0.1.2, experimental,
  ~420 stars, and its author has paused development for a thesis. **Pleamar**
  (Rust/wgpu/Luau, BSD-3) was created 2026-09-19, ~200 stars,
  has per-plugin threads and a Marea example shell, and calls itself an alternative to Quickshell.
  **AGS/Astal** is GTK, TypeScript via GJS, v3 current, mature, but the Hyprland wiki lists
  performance and script reliance as its weak points. **Fabric** is Python on GTK3. **Eww** is
  Yuck/GTK3 and rebuilds widgets on every variable change, which is why it degrades on complex
  layouts. **Waybar** is a bar only. **Quickshell** plugin ecosystems exist as products built on it:
  DankMaterialShell has a manifest-based plugin registry (widget/daemon/desktop/composite
  types), and Noctalia v5 ships its own.
  Noctalia v5 ships its own. This repo already has a home-grown mechanism: `plugins.json` plus
  `plugins/<name>.qml`, with `swayncIndicator.qml` as the only entry, in a 72-line `shell.qml`.

- 2026-11-11T20:25Z [TOOL] The "Hyprland crashes during idle" report splits into two unrelated
  events.
  (1) **hyprlock** aborts: `coredumpctl` shows `SIGABRT`, `SI_TKILL`, `raise -> abort -> libstdc++`
  at 2026-11-03 17:05:23 and 2026-11-10 13:49:09, and both timestamps coincide to the second with
  an `amdgpu ... MODE1 reset` inside a `systemctl suspend` started by hypridle's 1800 s listener.
  So the lockscreen dies because suspend triggers a GPU reset, and hyprlock's GL context goes with
  it; Hyprland then keeps a crashed-lockscreen state that only `hl.clear_crashed_lockscreen()` plus
  `killall -9 hyprlock` clears.
  (2) **Hyprland** SIGSEGV: 46 cores retained between 2026-10-14 and 2026-11-11, and an automated
  cross-check against the journal matched **46 of 46** to a `uwsm ... Stopping compositor` line
  within 5 s. Every one crashed in `Aquamarine::CDRMBackend::flushAsyncCommitEvents` during
  destructor teardown, i.e. at session exit, never during use. Cosmetic, but it fills the coredump
  store and makes real crashes hard to spot.

- 2026-11-11T20:25Z [TOOL] Live RAM census on this machine (31 GiB total, 4.2 GiB used):
  Hyprland 181 MB, quickshell 173 MB, Xwayland 79 MB, swaync 46 MB, hypridle 7 MB — desktop chrome
  totals roughly 490 MB, about 1.5% of RAM.

- 2026-11-11T20:25Z [TOOL] Noctalia v5 (C++/OpenGL ES, stable 5.0.1 on 2026-09-03) claims about
  one-sixth of v4's per-monitor memory, from roughly 300 MB/monitor; a community report measures
  ~160 MB idle on two screens against ~285 MB for a Quickshell config. v4 QML plugins do not port
  to the new plugin API. Umbriel (same team, wlroots 0.20, C++23, repo created 2026-08-02) is
  explicitly labelled young with changing configuration, and niri has no plugin system at all.
  Hyprland remains the only one of these with a real compositor plugin ABI, at the cost of
  rebuilding plugins on every Hyprland/aquamarine bump.

- 2026-11-11T16:05Z [TOOL] Deployment state, verified without network: dev `main` equals
  `origin/main` at `d53f205`; the deployed clone tracks the same branch, has **no local commits
  ahead**, and sits five commits behind. Those five commits touch only `docs/` and `install/` —
  none touch `dotfiles/`, so the desktop's configs are identical and the lag is operational, not
  visual. Concrete gap: the deployed clone has no `install/amdgpu-late.service` even though the
  running kernel command line masks `amdgpu-late.service`. A fast-forward pull there is safe
  because no incoming commit modifies `hypridle.conf`.

- 2026-11-11T15:50Z [TOOL] The live dotfiles are **not** this clone. Every stow symlink under
  `~/.config` resolves into `/home/work/LuicipherOS` (remote `https://github.com/lui-do/...`),
  while this session works in `/home/work/dev/personal/projects/IT/LuicipherOS` (remote
  `git@github.com:...`). The deployed clone sits at `7652116` (2026-10-04) and is strictly behind
  this one at `d53f205` (2026-10-06) by five commits: the DMUB case file, the amdgpu late-load
  unit, the SIGPIPE-proof AMD gate, the ReBAR check fix, and the DMUB saga docs. Tracked dotfiles
  are otherwise identical, so the desktop's appearance was unaffected, but no dotfile edit made
  here reaches the running session until it is committed and pulled there, or copied. The deployed
  clone was five commits behind at the time; see the 16:05Z entry.

- 2026-11-11T15:50Z [TOOL] `hyprctl dispatch exec "cmd"` fails on Hyprland 0.57 when the
  argument contains shell syntax: dispatch is translated to Lua and the shell string is parsed as
  Lua. `hyprctl dispatch exec hypridle` is accepted but silently starts nothing. Starting a daemon
  from the CLI needs `setsid -f <cmd>` instead; that is how `hypridle` was restarted.

- 2026-11-11T15:50Z [TOOL] The deployed clone accumulates Tabby runtime state inside the stow
  package (`dotfiles/tabby/.config/tabby/{Cookies,Cache,Local Storage,...}`, all untracked). The
  live app writes into the source tree; a future `git add -A` there would commit browser profile
  data.

- 2026-11-11T14:20Z [TOOL] Web research on failure class A: the same signature is publicly known.
  omarchy issue #5478 (`Refused to change power state from D3hot to D0` -> `HC died` -> `SMU: No
  response` -> `Failed to disable gfxoff!` -> gfx ring timeout with the compositor) on Strix Halo;
  Red Hat bug 2457514 (Ryzen AI Max+ 395 / 6.19, same D3hot-D0 xHCI refusal); Arch BBS thread
  258806; an upstream amdgpu tracker work item 5171 (blocked by anti-bot, not read directly). No
  upstream fix and no merged patch; only workarounds. Most public reports are APUs and laptops, so
  a Navi 31 desktop card matching the `.2` USB-C function is a rarer variant, not an unknown one.

- 2026-11-11T14:20Z [TOOL] Workarounds seen upstream, relevance to this machine:
  `amdgpu.ppfeaturemask=0xfff73fff` (disables the SMU feature whose wake fails; the supported
  successor to the removed `amdgpu.gfxoff=0`) - plausible one-shot boot-parameter candidate;
  disabling VA-API video decode in browsers - the desktop has no `*-flags.conf`, and
  `radeonsi_drv_video.so` is present, so code/helium/tabby can use it, but this only reduces
  trigger frequency; VRAM carve-out increases - APU only, irrelevant here; avoiding 1 Hz GPU
  monitoring tools - already not in use. None of these fix the D3hot refusal itself.

- 2026-11-11T13:14Z [TOOL] Controlled reproduction: writing `on` to
  `/sys/bus/pci/devices/0000:03:00.2/power/control` at 12:28:07.812 immediately forced the broken
  transition. 25 ms later: `xhci_hcd 0000:03:00.2: Refused to change power state from D3hot to D0`,
  then `Controller not ready at resume -19`, `PCI post-resume error -19!`, `HC died; cleaning up`.
  The write to `03:00.1` at 12:28:07.791 produced no error, so `03:00.2` is the culprit function.

- 2026-11-11T13:14Z [TOOL] Cascade after that refusal: `i2c-designware-pci 0000:03:00.3`
  timeouts (12:28:07.855), first `DMCUB error` (12:28:08.100), `SMU: No response msg_reg: 29
  resp_reg: 0` and `Failed to disable gfxoff!` (12:28:15.9), `ring gfx_0.0.0 timeout` naming
  `Process Hyprland pid 3411` and `device wedged, but no recovery needed` (12:28:28.4),
  `EDID CEA parser failed`, then `Hyprland has crashed` (12:28:30). Journal continued to 12:29:43;
  cold boot at 12:31:13.

- 2026-11-11T13:14Z [TOOL] The desktop froze and Hyprland aborted, but **the kernel stayed alive
  for 95 s and kept logging**. This wedge therefore produces a compositor crash and a dead screen,
  not an instant platform reset. It is not the same failure as the `0x00800800` hard reset.

- 2026-11-11T13:14Z [TOOL] The upstream bridges (`00:01.1`, `01:00.0`, `02:00.0`) are `active`,
  so the refusal is not a powered-down parent port; the card's own function refuses to leave
  D3hot. `03:00.1`, `03:00.2` and `03:00.3` sit in D3hot almost continuously and are only harmful
  when something forces them to wake.

- 2026-11-11T13:14Z [ASSUMPTION] Three separate failure classes now stand: (A) D3hot->D0 refusal
  -> GPU wedge -> desktop freeze, reproduced and understood; (B) shutdown stall -> teardown
  cascade, plausibly a consequence of A; (C) `0x00800800` instant platform reset, still unexplained
  and most likely power/memory/firmware rather than this wedge.

- 2026-11-11T11:11Z [USER] The printer on the strip is an HP DeskJet 3630 inkjet, so printer fuser
  transients are eliminated. The strip is a cheap unbranded unit of unknown age; its 2300 W rating
  is not a limiting factor, but contact quality is unmeasurable.

- 2026-11-11T11:11Z [TOOL] Live power-state census of the four GPU functions: `03:00.0` amdgpu
  is `control=on`/`active` because `amdgpu.runpm=0`; `03:00.1` snd_hda_intel, `03:00.2` xhci_hcd and
  `03:00.3` i2c-designware are all `control=auto` and `runtime_status=suspended`, i.e. sitting in
  D3hot. `03:00.1` was already suspended ~48 s into the boot and stayed there.

- 2026-11-11T11:11Z [TOOL] The D3hot precondition for the observed refusal is therefore present
  on every idle session, not only on 2026-10-31. A runtime `power/control=on` on `03:00.1`,
  `03:00.2` and `03:00.3` removes it without reboot, package change or boot-entry change, and is
  reversible by writing `auto` back.

- 2026-11-11T10:05Z [USER] The 2026-11-11 00:12 shutdown completed with no stall or tty error
  output. The power strip is rated 230 V / 10 A / 2300 W and carried desktop, monitor, printer and
  sometimes a phone charger; the desktop has now moved to a wall socket. Monitor and printer remain
  on the strip.

- 2026-11-11T10:05Z [TOOL] Boot `546bc4e2` (2026-11-10 22:38:20 to 2026-11-11 00:12:46,
  1 h 34 min) shut down cleanly with no suspend, no power-state refusal, and no DMUB, vblank, xhci
  or CORB messages. The 2026-10-27 stall happened after a 3 h 04 min session. Shutdown stalls are
  therefore intermittent, and one clean shutdown does not clear the GPU power-state hypothesis.

- 2026-11-11T10:05Z [TOOL] The current boot reports no `Previous system reset reason` line at all,
  because unplugging the PSU to move the machine cleared the register. Absence of that line is not
  evidence of a clean or unclean shutdown.

- 2026-11-11T10:05Z [TOOL] DPMS-off cannot be correlated from logs: `hyprctl dispatch dpms` is a
  compositor action and writes nothing to the journal. Idle state must be recorded by hand.

- 2026-11-10T23:10Z [TOOL] The 2026-10-27 17:40 shutdown photos are boot `470c7a3f`
  (linux 7.2.8-arch1-2, started 14:36:40, uptime 11026 s). It is a normal `poweroff` that
  reached `Reached target System Power Off` and then stalled; it is not a reset. Boot indices in
  this log are relative to the reading moment and shift on every reboot; prefer boot IDs.

- 2026-11-10T23:10Z [TOOL] That trace is a teardown cascade on the GPU's own PCI functions:
  `xhci_hcd 0000:03:00.2 ... Controller not ready at resume -19` / `HC died`, `snd_hda_intel
  0000:03:00.1: CORB reset timeout#2, CORBRP = 65535`, and `amdgpu ... vblank wait timed out on
  crtc 0` / WARNING at `drm_vblank.c:1329` from `drm_fb_helper_damage_work`. The card loses power
  first; the drivers notice afterwards.

- 2026-11-10T23:10Z [TOOL] `journalctl` never contains that trace: journald stops during unmount,
  before `Reached target System Power Off`, so the kernel teardown output exists only on the tty.
  Grepping the journal for `CORB reset timeout` or `vblank wait timed out` returns nothing.

- 2026-11-10T23:10Z [TOOL] Reset-reason census over 56 retained boots (2026-10-14 to 2026-11-11):
  `0x00800800` internal CPU shutdown on 2026-10-19 19:36, 2026-10-27 14:25, 2026-11-05 13:23, and
  2026-11-10 22:36; `0x00080800` (software wrote `0x6` to CF9) on 2026-10-20, 10-31, 11-06; normal
  shutdowns report `0x00200800` ACPI transition. Boots with no reason line correspond to manual AC
  cuts, which clear the register.

- 2026-11-10T23:10Z [TOOL] The hard-reset class predates the 2026-10-31 11:42 upgrade of
  linux 7.2.11 + mesa 26.2.6 by six and twelve days. A 7.2.11/mesa regression is therefore ruled
  out as the cause.

- 2026-11-10T23:10Z [TOOL] Boot `74493bdd` (2026-10-31, LTS 6.18.59) is the only retained boot
  with the DMUB error storm, and its seed is a power-state refusal:
  `xhci_hcd 0000:03:00.2: Refused to change power state from D3hot to D0`, then dead xhci,
  `i2c-designware-pci 0000:03:00.3` timeouts, `snd_hda_intel 0000:03:00.1: Refused to change power
  state from D0 to D3hot` (twice), then 604 `Error queueing DMUB command: status=2` plus
  `dc_dmub_srv_log_diagnostic_data` between 70 s and 803 s.

- 2026-11-10T23:10Z [TOOL] PSR is not in play on this desktop: every connector reports
  `PSR support 0, DC PSR ver -1, sink PSR ver 0, DPCD caps 0x0`. The common
  `amdgpu.dcdebugmask=0x210` PSR workaround therefore cannot apply here.

- 2026-11-10T23:10Z [TOOL] The GPU USB-C controller (`usb1`/`usb2` under `0000:03:00.2`) has no
  attached devices; `snd_hda_intel` runs `power_save=10` with `power_save_controller=Y`, and that
  HDA function is refusing `D0 -> D3hot` transitions.

- 2026-11-10T23:10Z [USER] The "blank start" failures are AFK events: the monitor powers down, a
  keypress produces nothing, and the user performs a hard power-off. Routine hard power-offs are
  therefore the user's response to a display-wake failure, not spontaneous resets.

- 2026-11-10T22:28Z [USER] Hard resets occur without the `pi` agent, are self-initiated, and
  reach the ASUS TUF POST screen. Shutdown on both 7.2.11 and 6.18.59-lts shows DMUB errors for
  minutes before the machine powers off.

- 2026-11-10T22:28Z [TOOL] `/sys/fs/pstore/` is empty after the 2026-11-10 reset. `upower -e`
  lists only `DisplayDevice`; no UPS is exposed to the OS. `upower`/`lsusb` cannot rule out a UPS
  without a USB link.

- 2026-11-10T22:28Z [TOOL] Boot `-2` suspended at 12:11:57 and resumed at 13:49:09 with an
  amdgpu MODE1 reset; hyprlock then crashed. This is a GPU power-transition failure, related to
  issue #12 but distinct from the hard reset.

- 2026-11-10T10:20Z [TOOL] No `.agent/` directory or `CONTINUITY.md` existed before this entry;
  no automated dependency scanner or CI configuration exists in the repo yet
  (`[NEEDS TEAM INPUT]`).

- 2026-11-03T08:57Z [USER] User reports choosing the default late-load entry (called
  `arch-lateload` in this conversation); supplied command line matches the workaround.
  Exact entry filename and persistent default setting have not been independently read.

- 2026-11-03T08:57Z [ASSUMPTION] Existing conversation summary counts three blank starts
  among four selected starts after amdgpu sessions (Oct 31, Nov 1 and Nov 3 blank; Nov 2
  normal). This is a small observational series, not proof of a causal relationship.
  No saved boot for the Nov 3 failed attempt is visible; this does not prove the kernel
  never ran or establish the failure stage.

- 2026-11-03T08:57Z [USER] The earlier grep `amdgpu.*(probe|initializ)` matched the kernel
  command line. The narrower `amdgpu 0000` grep returned the PCI-device enabling message
  at 415.378081 s. Reaching the desktop does not establish an error-free kernel log.

- 2026-10-31T10:51Z [USER] The journal of the previous boot shows a complete shutdown
  (filesystems unmounted, journal flushed) before the hang, so the stall came at the last
  reboot step or at firmware start. The failed attempt left no journal (not in
  `journalctl --list-boots`). The watchdog message on reboot is harmless.

- 2026-10-31T10:50Z [USER] Desktop has two accounts: `work` (no sudo) and `luci` (admin).
  `flatpak --user` lists and dotfiles are per account, so run `sync.sh` as the daily account.

- 2026-10-31T10:50Z [USER] Installing qemu before `-Syu` failed with a gstreamer partial-upgrade
  conflict; a full `pacman -Syu` fixed the version skew. Always upgrade fully first.

- 2026-10-31T10:50Z [USER] `bootctl list`: `/boot` is the ESP (outside Btrfs). Main entry
  options include `amdgpu.runpm=0`; the `arch-lts` entry does not. The main entry's initrd
  list shows no `amd-ucode.img` while the LTS entry has it; microcode loading on the main
  entry is UNCONFIRMED (`microcode: Current revision: 0x0b40403b`, no update line).

- 2026-10-31T10:50Z [TOOL] Hyprland 0.57.0 drops legacy `.conf`; repo is already Lua-only.

- 2026-10-31T10:50Z [USER] `docker-compose` is installed by hand and not in the lists; Docker
  engine presence UNCONFIRMED. Podman 6.1.x is installed and not in the lists.

- 2026-10-31T10:07Z [TOOL] `TESTING.md` mentions `tests/test_sync.sh` as planned, but the file
  already exists in `tests/`; run instructions UNCONFIRMED.

- 2026-10-31T10:07Z [TOOL] `main` is the only branch and is unprotected; no CI present.

- 2026-10-06T13:32Z [CODE] Cold boot hangs ~4s into init (`SMU: No response`, DMUB status=2).
  Warm reboots are clean. Soft blacklist + late modprobe initialized clean twice; the
  systemd-unit variant stormed once.

- 2026-10-06T13:20Z [CODE] DMUB cold-boot loop is a firmware regression:
  `linux-firmware[-amdgpu] 20260916` is bad, `20250708` is clean. Warm reboots mask it; failed
  boots leave no journal. Disabling ASPM, IOMMU, or ReBAR does not help.

- 2026-10-06T13:20Z [CODE] `lspci | grep -q` is unsafe under `set -o pipefail`: early grep exit
  sends SIGPIPE and produces false negatives. Capture the output first, then search it.

- 2026-10-05T18:02Z [CODE] Firmware bisection: 20250708 good / 20260916 bad (later casefile
  says loops on both; one clean boot likely a fluke).

- 2026-10-04T14:46Z [CODE] `grep -q` + pipefail false-failed on a present GPU (SIGPIPE); same
  trap fixed in the AMD gate on 2026-10-06T11:36Z.

- 2026-10-03T10:11Z [CODE] Prompt chatter on stdout poisoned captured passwords (two lockouts);
  prompts must go to stderr.

- 2026-09-28T01:23Z [CODE] The ISO live environment needs `linux`, `mkinitcpio-archiso`,
  `systemd-sysvcompat`, `archlinux-keyring`, `reflector`, `openssh`, `iputils`, `pciutils`, and
  `terminus-font`; creds prompt needs confirmation; keyring must be ensured with `--skip-wkd`.

- 2026-09-26T14:59Z [CODE] `sector_size: null` triggers `TypeError` in
  `SectorSize.parse_args`; there is no `Percent` unit; `boot` alone does not satisfy ESP detection
  (`is_esp` checks the `esp` flag).

- 2026-09-26T14:59Z [CODE] `systemd-boot-pacman-hook` is gone from the repos (Sep 2026);
  kernel-install handles entries and `bootctl update` is the manual follow-up after systemd
  upgrades.

- 2026-09-26T14:59Z [CODE] AUR `-bin` packages are required for reliability: vicinae source
  parallel LTO OOM-kills `cc1plus` on ≤3 GB machines, and Tabby source builds all of Electron.

- 2026-09-26T00:00Z [CODE] archinstall schema traps: sector_size object, no Percent unit, esp
  flag required (details in AGENTS.md Code Style).

## [OUTCOMES]
- 2026-11-14T21:54Z `[TOOL]` **Kernel 7.3.4 verified clean after the upgrade.** Rebooted into
  `7.3.4-arch1-1`; `/proc/cmdline` still carries `modprobe.blacklist=amdgpu
  systemd.mask=amdgpu-late.service 3` (the static `arch-lateload.conf` entry survived the swap);
  amdgpu late-loaded (DMUB `0x07003300` at ~800 s, SMU initialised), **zero** amdgpu/DMUB/PM error
  lines, HDMI-A-1 driving the display, Hyprland now `0.57.2`. This boot's predecessor reset reason
  is `0x00200800` (clean ACPI transition from the deliberate reboot). The reset census from here on
  runs on 7.3.4; the pre-upgrade 7.2.11 events remain the baseline.
- 2026-11-12T13:13Z `[USER]` Asked whether the `luci` admin account can be renamed to `lui`.
  Answered and written up as `docs/rename-admin-account.md`: possible, and safer than a typical
  rename because
  `usermod -l` keeps the UID so file ownership is unaffected, but **blocked** because `usermod`
  refuses to rename a user with running processes and `luci` is the only sudoer. Recommended
  approach is a temporary second `wheel` account; recommended decision is **do not rename now**,
  since it is cosmetic and the shared-tree work makes the account name irrelevant. Also recorded
  that `work` **is** in `wheel` and is blocked only by having no usable password.

- 2026-11-11T16:35Z [TOOL] The hypridle change is committed as `c9bca0a` ("fix(hypr): drop
  DPMS-off and auto-suspend listeners") touching only that one file; `chmod 644` was restored
  first so the commit carries no mode change. The deployed clone was fast-forwarded from the local
  dev clone
  (`git pull --ff-only <dev-path> main`), because the harness denies `git push`. Both clones now sit
  at `c9bca0a`, six commits ahead of `origin/main`; the deployed clone is clean. Push to GitHub
  remains for the user to run.

- 2026-11-11T16:35Z [TOOL] The dev clone's working tree carries pre-existing unrelated work that
  must not be swept into commits: 166 modified files, mostly `.agents/skills/**` mode changes
  644->755, plus real edits in `.gitignore`, `AGENTS.md`, and two deleted `iso/airootfs`
  symlinks. `.agent/CONTINUITY.md` is untracked. Always commit here with an explicit pathspec.

- 2026-11-11T15:50Z [TOOL] `hypridle` now registers exactly one rule (600 s lock), verified with
  `hypridle -v` before starting, then started detached as PID 90734. The file was written in both
  clones so they stay identical. The change is uncommitted in both; the deployed clone was clean
  before this.

- 2026-11-11T15:50Z [ASSUMPTION] Screen blanking is now the monitor's own OSD power-saving
  timer, which does not involve the GPU. Software blanking would re-add the failing transition and
  must not return without a verified recovery path.

- 2026-11-11T13:14Z [TOOL] REJECTED: `power/control=on` as a mitigation. Writing `on` to an
  already-suspended function is itself the failed D3hot->D0 transition, so the test is an
  injection, not a passive change. Never apply it after the device has suspended. Supersedes the
  11:11Z promotion below.

- 2026-11-11T13:14Z [ASSUMPTION] Do not force GPU wakes again. If runtime PM is ever disabled it
  must happen at PCI `add` time via udev, while the function is still in D0, and only with a
  verified recovery path. Low priority.

- 2026-11-11T11:11Z [ASSUMPTION] Demote the power-strip hypothesis: an inkjet printer draws
  ~10-25 W, the strip is rated far above the load, and none of the four reset timestamps match a
  print job. Keep the wall-socket arrangement as good practice but do not expect the trial to be
  diagnostic.

- 2026-11-11T11:11Z [ASSUMPTION] Promote the GPU PCI power-state path: the D3hot precondition is
  observable on every idle session, the refusal and the resulting DMUB storm are directly observed,
  and the reset timestamps include light-load moments 6-9 minutes after boot. Pending user approval,
  the next single-variable test is `power/control=on` on `03:00.1`, `03:00.2`, `03:00.3`.

- 2026-11-10T23:10Z [ASSUMPTION] Supersedes the 22:28Z entry below: the linux-firmware 20250708
  downgrade is no longer the highest-value test. The reset class predates the 2026-10-31 upgrade and
  the user declined downgrades. New order: power delivery (strip -> wall socket), GPU PCI
  power-state (`pcie_port_pm=off`, `snd_hda_intel.power_save=0`), then memory/EXPO, then firmware.

- 2026-11-10T23:10Z [ASSUMPTION] The shutdown stall, the DMUB error storm, the AFK no-wake
  failures and the `0x00800800` reset all point at one class: the 7900 XT not completing PCI
  power-state transitions. Shared mechanism is plausible but the reset itself is still unproven;
  power delivery remains an equally open alternative and cannot be observed from software.

- 2026-11-10T22:28Z [ASSUMPTION] Treat the hard reset and the GPU shutdown/suspend failures as
  two tracks with a likely shared amdgpu/DMUB/firmware element. `linux-firmware` 20260916 was then
  considered the highest-value single-variable test; that ranking is now superseded above.

- 2026-11-10T10:30Z [TOOL] Canonical docs state: project `v0.1`, Unified Agent Prompts `v1.0`,
  blueprint `AGENTS.md`, operational log `.agent/CONTINUITY.md`, glossary `CONTEXT.md`, ADRs in
  `docs/adr/`.

- 2026-11-03T08:57Z [USER] Desktop recovered on the second start using the reported default
  late-load entry. Early-load DMUB/SMU behavior and the separate blank-start symptom remain
  unresolved. Today's error-check result is UNCONFIRMED.

- 2026-10-31T20:39Z [ASSUMPTION] Machine state since 13:48Z is UNCONFIRMED (user was away).

- 2026-10-31T10:07Z [CODE] Target machine: NOT YET PASSING; blocked by the DMUB cold-boot issue.
  Open inputs: PSU model/wattage, AIB board model, VBIOS updates, `amdgpu-late` disable test.

- 2026-10-31T10:07Z [CODE] AMD laptop and Intel laptop matrix entries: UNCONFIRMED (no results
  recorded).

- 2026-10-06T15:32Z [CODE] Cold-boot workaround shipped and documented; upstream report still
  needs the board model and VBIOS strings.

- 2026-09-28T01:23Z [CODE] Netinstall ISO path proven end to end in a VM; target-machine
  validation and ISO publication remain open.

- 2026-09-28T00:00Z [CODE] ISO loop: PASS.

- 2026-09-26T14:59Z [CODE] Five VM checkpoints green: Hyprland loads, SUPER+T Tabby,
  SUPER+Space Vicinae, SUPER+N swaync, Print region -> Gradia.

- 2026-09-26T00:00Z [CODE] VM smoke: PASS.
