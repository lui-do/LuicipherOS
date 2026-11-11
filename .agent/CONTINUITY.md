# CONTINUITY.md (Operational Log)

Survival briefing for agents. Read this before acting, append after acting.
Newest entries first within each section; entries are ISO-8601 UTC.
Provenance tags: `[USER]`, `[CODE]`, `[TOOL]`, `[ASSUMPTION]`. Unknown: `UNCONFIRMED`.
Times marked (approx.) were reconstructed from terminal screenshots and journal timestamps.
Record architectural changes here.

On 2026-11-11 this log was union-merged from two diverged copies (one holding the October
history, one holding the November detail); no entry was dropped.

## [PLANS]

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
  `luci sync --prune`; otherwise prune lists them as extras. Also add `dosfstools`.

- 2026-10-31T10:50Z [USER] TODO: inventory hand-installed packages/flatpaks with
  `./scripts/sync.sh --prune --dry-run` and sort into keep (add to lists) or remove.

- 2026-10-31T10:07Z [CODE] v0.1: target-machine installer + dotfiles + sync (README roadmap).

- 2026-10-31T10:07Z [CODE] v0.2: hardware profiles (`profiles/`), power/HiDPI, shell workspaces
  widget, tray, NotificationServer center (then drop swaync), screenshot tool decision.

- 2026-10-31T10:07Z [CODE] v0.3: optional Nix layer, `luci sync` as a binary, CI + VM matrix.

- 2026-10-31T10:07Z [CODE] Next on target: decide whether `amdgpu-late.service` helps; run
  `systemctl disable amdgpu-late` test (unrun per casefile). See the 2026-10-31T20:39Z entry:
  the unit is enabled on the desktop; its normal-boot test is now tracked in issue #11.

- 2026-10-31T10:07Z [CODE] Publish ISO only after one VM boot of the built artifact reaches
  archinstall (already met per TESTING.md; publish itself UNCONFIRMED).

- 2026-10-06T13:20Z [CODE] Keep the `amdgpu` late-load workaround until upstream fixes the DMUB
  cold-boot firmware regression; then unpin `linux-firmware`/`linux-firmware-amdgpu`.

- 2026-09-21T20:00Z [USER] v0.2 scope candidates: hardware profiles, power/HiDPI, shell
  notification center (to retire swaync), HiDPI monitor overrides, optional Nix layer (v0.3).

- 2026-09-21T20:00Z [CODE] v0.3 candidates: `luci sync` as a binary, CI plus VM test matrix.

## [DECISIONS]

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
  snapshot #1 "baseline before luci sync". Changes are on the machine, not yet in repo lists.

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
