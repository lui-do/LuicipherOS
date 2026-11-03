# CONTINUITY.md (Operational Log)

Survival briefing for agents. Newest entries last within each section.
Provenance tags: `[USER]`, `[CODE]`, `[TOOL]`, `[ASSUMPTION]`. Unknown: `UNCONFIRMED`.
Timestamps are ISO 8601 UTC. Record architectural changes here.
Times marked (approx.) were reconstructed from terminal screenshots and journal timestamps.

## [PLANS]

- 2026-10-31T10:07Z [CODE] v0.1: target-machine installer + dotfiles + sync (README roadmap).
- 2026-10-31T10:07Z [CODE] v0.2: hardware profiles (`profiles/`), power/HiDPI, shell workspaces
  widget, tray, NotificationServer center (then drop swaync), screenshot tool decision.
- 2026-10-31T10:07Z [CODE] v0.3: optional Nix layer, `luci sync` as a binary, CI + VM matrix.
- 2026-10-31T10:07Z [CODE] Next on target: decide whether `amdgpu-late.service` helps; run
  `systemctl disable amdgpu-late` test (unrun per casefile). See the 2026-10-31T20:39Z entry:
  the unit is enabled on the desktop; its normal-boot test is now tracked in issue #11.
- 2026-10-31T10:07Z [CODE] Publish ISO only after one VM boot of the built artifact reaches
  archinstall (already met per TESTING.md; publish itself UNCONFIRMED).
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
- 2026-11-03T08:57Z [ASSUMPTION] Pending blank-start observations: Caps Lock response,
  monitor-only power cycle and another HDMI input/port. Nov 3 results are not reported.
  DisplayPort and shutdown-path experiments remain proposals, not established fixes.
- 2026-11-03T08:57Z [ASSUMPTION] Next project task proposed in conversation: audit the five
  sync-script items from the inventory document after the docs update; scope still to verify.

## [DECISIONS]

- 2026-09-21T00:00Z [CODE] ADR-0001: Arch + declarative scripts for v0.1; Nix optional in v0.3;
  LFS learning only. Time of day UNCONFIRMED (date from ADR).
- 2026-10-31T10:07Z [CODE] Locked in grill (CONTEXT.md): Vicinae launcher (SUPER+Space), fuzzel
  fallback, Quickshell bar, Tabby, grim+slurp -> Gradia, swaync kept for v0.1, native Lua
  Hyprland config, yay-bin, split flatpak scopes, manual-only sync.
- 2026-10-02T19:11Z [CODE] Helium-only browser (`helium-browser-bin`), Firefox removed;
  greetd + tuigreet login; yazi picker shipped dormant opt-in; HyprCapture on HOLD.
- 2026-10-04T16:45Z [CODE] Czech QWERTY default (Hyprland cz+qwerty, console cz) with dual
  workspace binds for the Czech number row and Alt+Shift layout toggle.
- 2026-10-04T14:56Z [CODE] Installer falls back to a geo mirror on sync failure and retries once.
- 2026-10-06T10:09Z [CODE] amdgpu late-load unit added for the cold-boot DMUB race (AMD only);
  verdict pending target test.
- 2026-10-31T10:07Z [USER] Documentation standard: AGENTS.md (blueprint, fixed section order) and
  `.agent/CONTINUITY.md` (this log); Unified Agent Prompts v1.0.
- 2026-10-31T10:30Z [USER] Desktop snapshots: Snapper + snap-pac chosen over Timeshift
  (Timeshift expects an `@`/`@home`-only layout; this system also has `@log`, `@pkg`,
  `@snapshots`). Dev station: libvirt/QEMU VM for installer/boot tests, Podman container for
  script tests.
- 2026-10-31T13:15Z (approx.) [USER] systemd-boot menu timeout set to 10 s
  (`bootctl set-timeout 10`) so the menu shows on every boot.
- 2026-10-31T13:26Z (approx.) [USER] Interim GPU workaround: boot with
  `modprobe.blacklist=amdgpu systemd.mask=amdgpu-late.service 3`, wait about 190 s,
  `sudo modprobe amdgpu`, check dmesg, then `sudo systemctl start greetd`.
- 2026-10-31T13:45Z (approx.) [USER] Keep choosing the "Hyprland (uwsm managed)" session until
  the greetd default is fixed.
- 2026-10-31T13:48Z (approx.) [ASSUMPTION] A persistent boot entry `arch-lateload.conf` with
  the workaround parameters, set as default, was proposed. Whether it was created: UNCONFIRMED
  at that time. See the Nov 3 user report under [DISCOVERIES] for subsequent evidence.

## [PROGRESS]

- 2026-09-26T00:00Z [CODE] VM smoke PASS (QEMU/OVMF, 2026.09.01 ISO), five checkpoints green.
- 2026-09-28T00:00Z [CODE] ISO-loop PASS (own netinstall image -> archinstall 2m19s -> desktop).
- 2026-10-03T20:06Z [CODE] ISO re-verified on fresh Oct-02 artifact: all green incl. portal picker.
- 2026-10-04T08:33Z [CODE] Target hardware manifest added: TUF B650E-PLUS WIFI, 32G Apacer,
  1TB Kingston, RX 7900 XT.
- 2026-10-04T14:27Z [CODE] Installer skips connection setup when already online (closes #6);
  commented-out mirrorlists healed proactively (closes #7).
- 2026-10-06T12:05Z [CODE] ReBAR check trusts the mapped 32G BAR over sysfs node presence.
- 2026-10-06T13:32Z [CODE] DMUB cold-boot case file added for external research. Last commit
  before this entry: `d53f205`.
- 2026-10-31T10:07Z [TOOL] AGENTS.md rewritten to the 11-section template; this file created.
  Existing archinstall field notes and agent-skill pointers were preserved.
- 2026-10-31T10:30Z [USER] Desktop: Snapper root config created; `/.snapshots` remounted from
  `@snapshots` (subvolid 260); snapper-timeline and snapper-cleanup timers active; baseline
  snapshot #1 "baseline before luci sync". Changes are on the machine, not yet in repo lists.
- 2026-10-31T10:42Z [USER] Desktop: `pacman -Syu` (176 packages incl. hyprland 0.57.0,
  linux 7.2.11, linux-lts 6.18.59, systemd 262.1) wrapped by snap-pac pre/post snapshots
  #2/#3. `bootctl update` run; no `.pacnew`/`.pacsave` files. Reboot result: see below.
- 2026-10-31T10:51Z [USER] `systemctl reboot` from the 7.2.8 session: no video, no ASUS logo,
  Caps Lock dead; hard power-off needed. Details in [DISCOVERIES].
- 2026-10-31T12:35Z [USER] Cold boot to `linux-lts` with `nomodeset` worked (low-resolution
  firmware framebuffer).
- 2026-10-31T12:55Z (approx.) [USER] Warm reboot into `linux` 7.2.11 with no extra parameters:
  DMUB/SMU storm, Hyprland crash loop, no recovery; hard power-off.
- 2026-10-31T13:17Z (approx.) [USER] Installed `dosfstools`; `fsck.fat -n` showed the dirty bit
  and a boot-sector backup difference at offset 65 (mostly harmless); `fsck.fat -a` cleared
  the dirty bit; `/boot` remounted; both boot entries intact.
- 2026-10-31T13:26Z (approx.) [USER] Boot with `modprobe.blacklist=amdgpu
  systemd.mask=amdgpu-late.service 3`; manual `modprobe amdgpu` at about 186 s uptime
  initialized clean on 7.2.11. `systemctl start greetd` then reached Hyprland; the session was
  stable for 10+ minutes with no new DMUB/SMU lines.
- 2026-10-31T13:48Z [TOOL] Issue #11 created for the boot/GPU problem and follow-ups.
- 2026-11-03T08:50Z [ASSUMPTION] Earlier-session summary in this conversation records a blank
  Nov 1 power-on and a normal Nov 2 power-on. The assistant's existing issue #11 comment
  describes hard power-off recovery for Nov 1. These historical details were carried forward
  from that summary, not newly re-tested in this session.
- 2026-11-03T08:41Z [USER] Morning power-on showed a black screen with nothing appearing.
  After another power-off/power-on the boot options appeared and the user chose the default
  entry. Exact time of the failed attempt is UNCONFIRMED.
- 2026-11-03T08:49Z [USER] User reported being on the desktop.
- 2026-11-03T08:50Z [USER] Screenshot: saved boot -1 starts Nov 2 at 12:49:22 CET and ends
  at 23:01:28 CET; current boot starts Nov 3 at 09:40:22 CET. `uptime -s` reports
  2026-11-03 09:37:48 local time (08:37:48Z). No separate boot for the failed attempt is
  visible in the supplied list. Journal timestamps alone do not establish clean shutdown.
- 2026-11-03T08:50Z [TOOL] An update comment was posted to issue #11:
  https://github.com/lui-do/LuicipherOS/issues/11#issuecomment-6599309547 .
- 2026-11-03T08:54Z [USER] Supplied kernel command line includes `amdgpu.runpm=0
  modprobe.blacklist=amdgpu systemd.mask=amdgpu-late.service 3`.
- 2026-11-03T08:57Z [USER] Supplied monotonic journal line:
  `[  415.378081] LuicipherOS kernel: amdgpu 0000:03:00.0: enabling device (0006 -> 0007)`.
  First matching device message is about 6 min 55 s after kernel start. This is not a
  completed-initialization timestamp; the earlier error-check result remains unreported.

## [DISCOVERIES]

- 2026-09-26T00:00Z [CODE] archinstall schema traps: sector_size object, no Percent unit, esp
  flag required (details in AGENTS.md Code Style).
- 2026-10-03T10:11Z [CODE] Prompt chatter on stdout poisoned captured passwords (two lockouts);
  prompts must go to stderr.
- 2026-10-04T14:46Z [CODE] `grep -q` + pipefail false-failed on a present GPU (SIGPIPE); same
  trap fixed in the AMD gate on 2026-10-06T11:36Z.
- 2026-10-05T18:02Z [CODE] Firmware bisection: 20250708 good / 20260916 bad (later casefile
  says loops on both; one clean boot likely a fluke).
- 2026-10-06T13:32Z [CODE] Cold boot hangs ~4s into init (`SMU: No response`, DMUB status=2).
  Warm reboots are clean. Soft blacklist + late modprobe initialized clean twice; the
  systemd-unit variant stormed once.
- 2026-10-31T10:07Z [TOOL] `TESTING.md` mentions `tests/test_sync.sh` as planned, but the file
  already exists in `tests/`; run instructions UNCONFIRMED.
- 2026-10-31T10:07Z [TOOL] `main` is the only branch and is unprotected; no CI present.
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
- 2026-10-31T10:51Z [USER] The journal of the previous boot shows a complete shutdown
  (filesystems unmounted, journal flushed) before the hang, so the stall came at the last
  reboot step or at firmware start. The failed attempt left no journal (not in
  `journalctl --list-boots`). The watchdog message on reboot is harmless.
- 2026-10-31T12:55Z (approx.) [USER] The storm boot followed a session where amdgpu never
  loaded (`nomodeset`), so the GPU met the driver in the firmware-initialized state, like a
  cold boot. Errors: DMUB status=2, SMU "not done with previous command", VCN/JPEG power-gate
  failures, `Dpm disable uvd failed, ret = -62`, i2c-designware timeout, `Failed to disable
  gfxoff!`. Same signature as the casefile. Hypothesis only.
- 2026-10-31T13:08Z (approx.) [USER] `module_blacklist=amdgpu` on the kernel command line blocks
  even a manual `modprobe` (Operation not permitted); `modprobe.blacklist=` does not. An
  earlier instruction that mixed them up was wrong.
- 2026-10-31T13:08Z (approx.) [USER] `amdgpu-late.service` is ENABLED on the desktop (docs said
  DISABLED); it failed at boot under `module_blacklist=`. `/etc/modprobe.d/amdgpu-coldboot.conf`
  exists.
- 2026-10-31T13:26Z (approx.) [USER] Late load on 7.2.11: SMU initialized, DMUB hardware
  initialized version 0x07003300, `runtime pm is manually disabled`, console switched to
  240x67. `smu driver if version = 0x3d` vs `smu fw if version = 0x41` (firmware 20260916),
  not logged as an error.
- 2026-10-31T13:17Z (approx.) [USER] systemd-boot menu was hidden (timeout 0); holding Space
  shows it. `dosfstools` was not installed. The ESP dirty bit came from the hard power-offs.
- 2026-10-31T13:35Z (approx.) [USER] greetd runs `tuigreet --time --remember --cmd 'uwsm start
  hyprland'`; uwsm prints a notice (check may-start) and waits 5 s. Benign warnings seen:
  rtkit missing, regulatory.db missing, swaync config not found, UPower, webcam UVC.
- 2026-10-31T13:35Z (approx.) [USER] `coredumpctl` tail shows at least 7 Hyprland crashes
  (SIGSEGV/SIGTRAP) between Oct 28 and Oct 31 plus a hypridle abort, before and during the
  problem. Causes UNCONFIRMED.
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

## [OUTCOMES]

- 2026-09-26T00:00Z [CODE] VM smoke: PASS.
- 2026-09-28T00:00Z [CODE] ISO loop: PASS.
- 2026-10-31T10:07Z [CODE] Target machine: NOT YET PASSING; blocked by the DMUB cold-boot issue.
  Open inputs: PSU model/wattage, AIB board model, VBIOS updates, `amdgpu-late` disable test.
- 2026-10-31T10:07Z [CODE] AMD laptop and Intel laptop matrix entries: UNCONFIRMED (no results
  recorded).
- 2026-10-31T13:45Z (approx.) [USER] Target desktop usable via the late-load workaround.
  Normal boot path (default entry, enabled unit) still UNRESOLVED; tracked in issue #11.
- 2026-10-31T20:39Z [ASSUMPTION] Machine state since 13:48Z is UNCONFIRMED (user was away).
- 2026-11-03T08:57Z [USER] Desktop recovered on the second start using the reported default
  late-load entry. Early-load DMUB/SMU behavior and the separate blank-start symptom remain
  unresolved. Today's error-check result is UNCONFIRMED.
