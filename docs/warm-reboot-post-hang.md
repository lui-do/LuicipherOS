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

**Conclusion (2026-11-18):** the reset *mechanism* does not matter.

**CORRECTION (same day, after the firmware-reset test below): that conclusion was wrong.** The
reset mechanism was never actually varied:

- `reboot=c` sets a cold/warm *mode* hint. On x86 that is largely advisory; the reset *type*
  stayed at whatever the default is. So the "reboot=c" test was effectively a no-op.
- `reboot=t` (triple fault) resets the **CPU only**. It never signals the chipset or EC that a
  platform reset happened — which fits the dark Q-LEDs exactly.

So the only mechanism ever exercised was the default one, three times. ACPI/KBC cold reset
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

### Counter-evidence 2026-11-18: a reset driven by firmware itself POSTs fine

Procedure: power off → power on → Del into BIOS setup → "Discard Changes and Exit" → the boot menu
appeared normally. No OS was running when the reset was requested; the platform was warm (POSTed,
in setup), and it POSTed again afterwards.

This is the first time a warm reset has ever completed POST on this machine. What it proves and
what it does not:

- Proves the platform **can** POST warm. A cold power cycle is not the only way out.
- The remaining variable is therefore either **who drives the reset** (firmware/EC vs the OS), or
  **the state the OS leaves behind** (device/driver/power state at reset time).
- It is a single observation with one ambiguity: "Discard Changes and Exit" and "Discard Changes
  and Reset" are different menu items, and if the former merely continued the boot instead of
  resetting, the test proves nothing. Must be repeated with the explicit *Reset* item, several
  times, and timed — a genuine reset + POST takes several seconds, an instant menu means no reset
  happened.

**Live hypothesis (2026-11-18):** the reset requested by the OS never reaches the EC as a real
platform reset, while firmware's own reset does. Consistent with every data point: default/ACPI
reset hangs, triple fault (CPU-only) hangs, `reboot=c` (a mode hint, not a mechanism) changed
nothing, and the board sits dark with no POST sequence when the OS asks for a reset.

**Untested OS-side mechanisms** (x86 `reboot=` type letters, `Documentation/admin-guide/kernel-
parameters.txt`): `e` = EFI runtime `ResetSystem()` (delegate to firmware — closest analogue to
what just worked), `p` = PCI/chipset reset, `a` = force ACPI/FADT reset, `b` = BIOS real-mode
reset, `k` = keyboard controller. None of these has been tried.

Also note whether the GPU/CPU fans spin up, whether the board's power LED stays on, and whether a
monitor-only power cycle changes anything. Photograph the LED panel if it is easy.

## Reopened: OS-side reset mechanism ladder (2026-11-18)

Each attempt: cold boot (so the running kernel carries the param) → verify `/proc/cmdline` →
`sudo reboot` → record logo/menu, Q-LED state, fan state. Self-validating: after a hang,
`sudo journalctl -k -b -1 | grep -m1 'Kernel command line'` must show the param in the boot that
performed the reset. **Edit the options line in place, never append again** — accumulated params
are what produced two false negatives earlier.

| Order | Param | Result / what a success would mean |
|---|---|---|
| 0 | (default) | 6× hang |
| 1 | `reboot=t` | hung (CPU-only reset; never signals the EC) |
| 2 | `reboot=e` (EFI `ResetSystem`) | **hung 2026-11-18** — a valid x86 letter (`BOOT_EFI = 'e'`), so the test stands, but EFI reset may already be the default on a UEFI machine, in which case it repeats what we knew |
| 3 | `reboot=p` → CF9 | **next** — `p` selects `BOOT_CF9_FORCE`: writes the chipset's CF9 hard-reset port (`outb(cf9\|2,0xcf9)` then `outb(cf9\|6,0xcf9)`). AMI firmware exiting setup almost certainly uses this same hard-reset path, which makes it the top candidate |
| 4 | `reboot=a` | FADT RESET_REG — likely the ACPI default; a failure confirms the default path |
| 5 | `reboot=k` | keyboard controller `0x64/0xFE` |

**Result 2026-11-18 — `pci` (CF9 hard reset): no visible reset, and the *next cold boot also
failed*.** No reset observable, no Q-LED, no splash, no boot. Then: first power-on after the forced
power-off showed nothing; the **second** power-on reached the boot menu.

Interpretation and why it matters more than the mechanism result:

- If CF9 had been delivered, the machine would have reset and died in the usual way. "No reset" is
  the signature the plan predicted for an unimplemented port, but it needs one clarification: was
  the *screen* black (reset happened, platform dead) or was the last frame frozen (no reset at all)?
- The **cold-boot failure is the important half**. Until now "cold boot always works" was the
  bedrock assumption of this whole investigation. It is now "cold boot works *if* the power has
  collapsed far enough" — a forced power-button off does not discharge the rails (the PSU stays in
  standby, +5VSB alive), so the first power-on afterwards can behave like a warm start.
- The real boundary is therefore **not warm-vs-cold reset but insufficient rail discharge / EC
  state**. A clean ACPI S5 poweroff (PS_ON# deasserted, rails collapse) has never failed; a forced
  button-off is not equivalent, and cutting AC for 20–30 s definitely is.

Recovery protocol adopted from here: prefer `sudo poweroff`; if the machine is already stuck, unplug
the PSU cable, hold the power button 20–30 s, replug, then boot. Treat a first failed power-on after
a forced-off as *expected*, not as a new fault.

This also reframes the warranty sentence — "POST fails after any reset, and even on power-on, until
the rails are fully drained" is a stronger and more specific hardware claim than "warm reboot
hangs".

### Rails were up during the failure (2026-11-18)

Fans were spinning throughout the failed state. That is decisive for one question: the board **is**
powered — the PSU is delivering 12 V, the platform has main rails — and yet no Q-LED ever lights,
so the EC never begins the POST sequence.

Consequences:

- **Not a power-delivery failure and not a PSU latch.** The supply keeps supplying.
- The failure is the **EC/power-sequencing state machine getting stuck after a reset** and only
  clearing when the rails fully collapse (clean ACPI S5 has never failed; AC removal definitely
  clears it; a forced button-off may not, because +5VSB stays alive).
- Firmware-with-initiated reset works, firmware-without-OS reset (`ResetSystem()`) and every other
  kernel mechanism does not — consistent with the EC accepting one reset source and not the others.
- Every previous "no Q-LED" observation is now explained without invoking any device: the board is
  powered, idle, and never asked to POST.

Ruled out or demoted by this: GPU-as-cause for *this* symptom, memory training, boot device, PSU
as a supply fault. Elevated: EC firmware, and therefore the beta BIOS/AGESA the machine is running.

**Default confirmed 2026-11-18:** `/sys/kernel/reboot/type` = **`efi`**. Every failure so far —
including the `reboot=e` test — used UEFI `ResetSystem()`, so `reboot=e` repeated the default rather
than varying it. The firmware's own setup-exit reset, which worked, is *not* that path.

Writing `cf9_force` to the sysfs knob returned `EINVAL` on kernel 7.3.4, so CF9 has to be selected
on the command line as `reboot=p` (letter `p` = `BOOT_CF9_FORCE`); the sysfs names accepted by this
build still need probing (`acpi`, `kbd`, `pci`, `cf9`, …).

**Probe result 2026-11-18:** accepted = `acpi`, `kbd`, `bios`, `triple`, `pci`, `efi`; rejected =
`cf9`, `cf9_safe`. So this build exposes the command-line names in sysfs, not the `cf9_force`
spelling the ABI document describes. **`pci` therefore selects `BOOT_CF9_FORCE`** — the CF9 hard
reset (`outb(cf9|2,0xcf9)`, then `outb(cf9|6,0xcf9)`) — and can be tested with no boot-entry edit:
`echo pci > /sys/kernel/reboot/type` then reboot. Note the kernel falls back to KBD (then triple)
if the selected mechanism does not actually reset the machine.

**Faster iteration — no entry edits needed.** Linux ≥ 5.11 exposes the same setting at runtime:

```bash
cat /sys/kernel/reboot/type                  # what the machine currently uses
sudo sh -c 'echo cf9_force > /sys/kernel/reboot/type'
cat /sys/kernel/reboot/type
sudo reboot
```

Valid sysfs values: `bios acpi kbd triple efi cf9_force cf9_safe`. This also *answers* what the default is, and removes the boot-entry edit → cold boot → verify cycle that caused two earlier false negatives. Note the value does not survive a reboot; set it again per test.

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
