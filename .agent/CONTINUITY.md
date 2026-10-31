# CONTINUITY.md (Operational Log)

Survival briefing for agents. Newest entries last within each section.
Provenance tags: `[USER]`, `[CODE]`, `[TOOL]`, `[ASSUMPTION]`. Unknown: `UNCONFIRMED`.
Timestamps are ISO 8601 UTC. Record architectural changes here.

## [PLANS]

- 2026-10-31T10:07Z [CODE] v0.1: target-machine installer + dotfiles + sync (README roadmap).
- 2026-10-31T10:07Z [CODE] v0.2: hardware profiles (`profiles/`), power/HiDPI, shell workspaces
  widget, tray, NotificationServer center (then drop swaync), screenshot tool decision.
- 2026-10-31T10:07Z [CODE] v0.3: optional Nix layer, `luci sync` as a binary, CI + VM matrix.
- 2026-10-31T10:07Z [CODE] Next on target: decide whether `amdgpu-late.service` helps; run
  `systemctl disable amdgpu-late` test (unrun per casefile).
- 2026-10-31T10:07Z [CODE] Publish ISO only after one VM boot of the built artifact reaches
  archinstall (already met per TESTING.md; publish itself UNCONFIRMED).

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

## [OUTCOMES]

- 2026-09-26T00:00Z [CODE] VM smoke: PASS.
- 2026-09-28T00:00Z [CODE] ISO loop: PASS.
- 2026-10-31T10:07Z [CODE] Target machine: NOT YET PASSING; blocked by the DMUB cold-boot issue.
  Open inputs: PSU model/wattage, AIB board model, VBIOS updates, `amdgpu-late` disable test.
- 2026-10-31T10:07Z [CODE] AMD laptop and Intel laptop matrix entries: UNCONFIRMED (no results
  recorded).
