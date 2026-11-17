# Warm reboot hangs UEFI POST — investigation (Nov 2026)

Symptom: `sudo reboot` results in no ASUS logo, no boot menu, no keyboard (Caps Lock dead)
= UEFI POST never completes. Cold boot (poweroff → power button) always works.

This is a **separate issue** from the DMUB cold-boot storm
(see `docs/dmub-coldboot-casefile.md`) and from the spontaneous `0x00800800` resets.

## Verified facts (2026-11-16)

### Boot entries on the ESP

| Entry | Origin | Options (root part) | GPU params |
|---|---|---|---|
| `2026-10-04_17-11-07_linux.conf` ("Arch Linux (linux)") | archinstall-generated | `cryptdevice=PARTUUID=3eea…:root root=/dev/mapper/root zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs` | `amdgpu.runpm=0` |
| `arch-lateload.conf` | hand-written | **identical root params** | + `amdgpu.ppfeaturemask=0xffff7fff modprobe.blacklist=amdgpu` (+ `reboot=c` since 2026-11-15) |
| `arch-lts.conf` | hand-written | same root params | none |

`loader.conf`: `default arch-lateload.conf`, `timeout 3`.

### Initramfs state

- `initramfs-linux.img` built **2026-11-15 13:55:20** (kernel 7.3.4-arch1-2 install).
- Contains the unlock tooling: `hooks/encrypt`, `usr/bin/cryptsetup` (3 cryptsetup entries).
- `pacman.log`: no `command failed to execute` in any recent transaction → the build succeeded.
- `/etc/mkinitcpio.conf`: `HOOKS=(base udev autodetect microcode modconf kms keyboard keymap
  consolefont block encrypt filesystems fsck)` — busybox `encrypt` hook, **not** `sd-encrypt`.
  Therefore `cryptdevice=` is the correct syntax on this system.
- ESP: 133 M used of 1022 M (890 M free).

### Kernel/mkinitcpio versions

`linux 7.3.4-arch1-2`, `mkinitcpio 42.2-1`, `cryptsetup 2.8.8-2`, `systemd 262.2-1`.

### LUKS panic (three occurrences, 2026-11-16 22:24 / 22:26 / 22:42)

```
VFS: Cannot open root device "/dev/mapper/root" or unknown-block(0,0): error -19
Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```

- Happens at ~1.6–2.5 s, i.e. before any GPU driver (amdgpu first prints at ~179 s).
- `error -19` = ENODEV: the mapper device was never created.
- Occurred while `arch-lateload.conf` carried the Phase-2 experiment params
  (`amdgpu.tmz=0 amdgpu.sg_display=0 amdgpu.dcdebugmask=0x10 iommu=soft`) — and only on that
  entry; the archinstall entry booted with the **same** initramfs and **same** root params.
- The panic report's log begins at ~0.49 s (front-truncated), so absence of a passphrase prompt
  in the capture does NOT prove the prompt never appeared.

### Disproved hypotheses

1. **Wrong LUKS hook family** — false. `HOOKS` uses busybox `encrypt`; `cryptdevice=` is correct.
2. **Broken/stale initramfs** — false. Built successfully 13:55, contains `cryptsetup`,
   no failed package hooks.
3. **Different initrd per entry** — false. All non-LTS entries use `/initramfs-linux.img`.
4. **Entry differs in root/LUKS params** — false. Root params are byte-identical between
   the archinstall entry and `arch-lateload.conf`.

### Leading suspect for the panic

`iommu=soft` is the only Phase-2 param that can affect early userspace (it changes IOMMU
handling for all DMA, before LUKS unlock). Unverified. It stays out of the boot line.

## Warm-reboot evidence so far

| When | From which entry | Result |
|---|---|---|
| 2026-11-12 | (pre-unload-unit era) | POST fine |
| 2026-11-15 | `arch-lateload` + unload unit + MCR off | hung |
| 2026-11-15 | `arch-lateload` + unload unit + MCR off + `reboot=c` (from reboot=c kernel) | hung |
| 2026-11-16 | `Arch Linux (linux)` (archinstall entry) | **POST fine, logo + menu appeared** |
| 2026-11-17 | archinstall entry, unload unit **enabled** | hung (no logo, no menu) |
| 2026-11-17 | archinstall entry, unload unit **disabled** | hung (no logo, no menu) — **unit exonerated** |
| 2026-11-18 | `reboot=t` (triple fault) on the archinstall entry | hung (no logo, no menu) — **validated, see below** |

### Validation of the 2026-11-18 test

The trap that produced two earlier false negatives was a kernel that never carried the test
parameter. `journalctl -k -b -1` for the boot that performed the reboot (11:05:05 → 11:09:55):

```
Kernel command line: initrd=\initramfs-linux.img cryptdevice=PARTUUID=3eea…:root
  root=/dev/mapper/root zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs
  amdgpu.runpm=0 reboot=t
```

The only entry under `Unknown kernel command line parameters` is `cryptdevice=…`, which is benign
and expected: the kernel proper does not consume `cryptdevice=`; the initramfs `encrypt` hook reads
it back from `/proc/cmdline`. `reboot=t` is *not* in that list → the kernel accepted the parameter
and requested the triple-fault reset. Boot sequence corroborates: boot −2 ended 11:03:11, boot −1
(test) ran 11:05:05–11:09:55, current boot began 11:14:09 after the power button — a ~4 min gap
consistent with a POST hang.

Residual caveat: logs cannot prove the CPU physically triple-faulted (the kernel could still fall
through to another reset path). It does not change the reading: a triple fault resets the CPU but
leaves the platform exactly as a power cycle would have changed it — and that is the point.

**Conclusion (2026-11-18):** the reset *mechanism* does not matter. ACPI/KBC cold reset
(`reboot=c`) and a CPU triple fault (`reboot=t`) both leave the machine unable to POST, while a
power cycle always succeeds. The software ladder is exhausted:

| Lever | Result |
|---|---|
| MCR off (BIOS) | no effect |
| `reboot=c` (KBC cold reset) | no effect |
| `reboot=t` (triple fault, bypasses firmware handshake) | no effect |
| RDNA3 params (`tmz`/`sg_display`/`dcdebugmask`/`iommu=soft`) | never validly tested; entry panicked; dropped |
| Unload unit enabled / disabled | no effect either way |
| archinstall entry vs hand-written entry | no effect |

The strongest remaining reading: after any reset short of a power cycle, POST cannot complete — so the
fault is in platform initialisation (GPU / EC / PSU state left behind by a reset), not in how the
reset is requested.

Note: from 2026-11-17 the hang has been observed from **both** entries, so the boot entry is
not the variable — the failure is at POST/firmware level, before any loader entry is read.
The 2026-11-16 success is therefore best treated as intermittent, not as evidence about a
specific entry.

### Hypothesis: the unload unit causes the hang

`amdgpu-unload-on-shutdown.service` removes the module at shutdown. That skips
`amdgpu_pci_shutdown()` — the driver's own quiesce + device reset. Left unfired, the GPU may be
handed to UEFI in a state that breaks GOP init on a warm reset. A cold boot works because the
PSU cycle resets the card in hardware.

Supporting: warm reboots were fine before the unit existed; every warm reboot with it enabled
hung; the one recent success came from a path that had not previously been tested with it.

Status: **hypothesis, unverified** — one controlled test decides it.

**Result 2026-11-17: DISPROVED.** With the unit disabled (driver left loaded, so
`amdgpu_pci_shutdown()` runs normally) the warm reboot still hung. Driver unload timing is
therefore not the trigger. Everything on the software side of the shutdown path is now cleared:
both entries hang, with and without the unload unit, with and without the GPU loaded at reset.

## Note on the late-load design

`/etc/modprobe.d/amdgpu-coldboot.conf` already contains `blacklist amdgpu`, so amdgpu never
autoloads on **any** entry; `amdgpu-late.service` is what loads it ~150 s after boot. The
`modprobe.blacklist=amdgpu` kernel parameter is therefore redundant, and a hand-written entry
duplicates what the archinstall entry + modprobe.d + unit already do. Planned simplification
(after the tests): move `ppfeaturemask`/`runpm` into modprobe.d options and let one entry exist.

## Observation that must accompany the next hang attempt

**Baseline on a healthy boot** (user-reported 2026-11-18): red → white → green. Mapping to ASUS
Q-LED order that is **CPU (red) → DRAM (yellow/amber, usually a blink) → VGA (white) → BOOT
(yellow-green)**. Green lingers for a while and the logo + boot menu appear the instant it goes
out — that lingering green is the firmware scanning for boot devices, i.e. normal for this board,
not a symptom.

During a hung POST the board's Q-LEDs (CPU / DRAM / VGA / BOOT, next to the 24-pin) report which
stage firmware is stuck in. This is free data and it discriminates between the remaining suspects:

| LED stuck on | Reading |
|---|---|
| **VGA (white)** | GPU init fails after reset → supports the GPU/`amdgpu`-left-state theory, and is the strongest single fact for a GPU-side warranty claim |
| DRAM (yellow) | memory training fails after reset → EXPO/memory-training territory (already EXPO-off, so suspicious) |
| CPU (red) | platform/microcode init fails → board or CPU |
| BOOT (green) | POST passed and stalled scanning the boot device → NVMe/firmware story, and the logo should have been visible |
| **no LED lit at all** | the board never started its POST sequence → EC / PWR_OK / PSU standby side, not a device |

### Result 2026-11-18: NO Q-LED lit at all — on every warm reboot attempted

User report: during the hang no Q-LED is lit and none blink, and this has been the case for **all**
warm reboots performed. Reading: the board never enters its POST sequence, so it dies *before* the
CPU stage. Consequences:

- The GPU is **not** in this chain: VGA init happens after CPU/DRAM, which never even light.
  (The DMUB cold-boot storm is a separate, OS-side issue and is unaffected by this finding.)
- Memory training, boot-device enumeration and everything loader/OS-side are likewise out.
- The failure is power-on sequencing: EC state after reset, PWR_OK, +5VSB, or the PSU's own
  protection/latch behaviour.
- It also explains the black screen trivially: firmware never runs, so no logo and no menu can
  appear, and no keyboard controller is initialised (Caps Lock dead).

Open sub-question that splits EC from PSU: during the hang, are **fans spinning** and is any
standby LED / powered USB port alive? Rails present + no POST = EC/firmware. Rails gone = PSU or
5VSB path.

Also note whether the GPU/CPU fans spin up, whether the board's power LED stays on, and whether a
monitor-only power cycle changes anything. Photograph the LED panel if it is easy.

## Hardware test plan (software ladder closed, GPU demoted)

Ordered by cost; one variable per session. **BIOS update is not available:** ASUS lists 4004
(2026-09-21, AGESA ComboAM5 PI 1.3.0.1d) as the newest build for this board and it is already
**beta** — the machine is on the latest firmware that exists. Earlier 3xxx releases carry
anti-rollback restrictions, so a downgrade to the last stable (3881) is not guaranteed to be
possible and needs approval either way.

1. **Does firmware's own reset hang?** Enter BIOS setup, press Esc → discard & exit (or F10 without
   changes). No OS involved, no risk. If the machine fails to POST after a *firmware-initiated*
   reset, the reset path is broken at EC/firmware level and no OS-side change can ever fix it —
   that is also the cleanest possible warranty statement.
2. **Rail/standby observation on the next hang** (free): fans spinning or stopped? standby LED or a
   USB port with a light still powered? Rails present + dark POST = EC; rails gone = PSU/5VSB.
3. **EC power-drain** (no settings lost): shut down, unplug the PSU cable, hold the power button
   20–30 s, replug, boot. First boot after may retrain memory and take longer — normal.
4. **Boot with the discrete GPU removed** (9600X has an iGPU; use the board's video output). If a
   warm reboot still hangs with no 7900 XT installed, the GPU is fully exonerated and the claim is
   board/PSU. Cheap, and decisive for where the RMA goes.
5. **Identify the PSU** — the case file has carried "PSU: UNKNOWN" since October. A label photo
   (brand, model, wattage, 12 V rail, age) is now a first-order diagnostic, and a swap test with any
   known-good unit is the definitive PSU check.
6. **BIOS `Ai Tweaker → PCIEX16(G5) Link Mode` → Gen4**, then **`IOMMU` → Disabled** — now lower
   priority, since neither can matter before the first Q-LED lights, but still cheap and reversible
   via `docs/bios-profiles/BEFOREMCR_CMO.CMO`.

Workaround that does not depend on any of the above: `sudo rtcwake -m off -s 60` (real S5 poweroff
plus RTC wake = the cold boot that always works, scriptable in one command). If the board does not
wake, the gate is `Advanced → APM Configuration → Power On By RTC`; baseline has ErP Disabled,
which normally keeps RTC wake alive.

Record for every attempt: logo yes/no, Caps Lock alive yes/no, Q-LED state, and afterwards
`journalctl -k -b -o short-monotonic | grep -m1 'Previous system reset'`.
