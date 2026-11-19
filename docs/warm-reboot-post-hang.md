# Warm reboot hangs UEFI POST — investigation (Nov 2026)

Symptom: `sudo reboot` results in no ASUS logo, no boot menu, no keyboard (Caps Lock dead)
= UEFI POST never completes. Cold boot (poweroff → power button) always works.

> **2026-11-19: an OS-initiated warm reboot WORKED.** Reset reason reported afterwards:
> `[0x00080800]: software wrote 0x6 to reset control register 0xCF9` — the ACPI/FADT hard reset.
> See "Breakthrough" below before reading the rest of this file.

This is a **separate issue** from the DMUB cold-boot storm
(see `docs/dmub-coldboot-casefile.md`) and from the spontaneous `0x00800800` resets.

> **Doing the work:** `docs/warm-reboot-action-plan.md` is the ordered runbook (recovery card, the
> EC/CMOS and firmware steps, what to record). This file is the evidence log.

## Breakthrough 2026-11-19: the reset reason code names the mechanism

The AMD SoC records **how the previous reset was performed**, and the kernel prints it on the next
boot:

```
x86/amd: Previous system reset reason [0x00080800]: software wrote 0x6 to reset control register 0xCF9
x86/amd: Previous system reset reason [0x00200800]: ACPI power state transition occurred
```

`0x00080800` = a software CF9 hard reset. `0x00200800` = the machine came from a power-on.

### Why this hid for a week

**After a hung reset the machine is power-cycled, and the power-on overwrites the reason code.** So
every failed warm reboot reported `[0x00200800]` — the *power cycle*, not the failed reset. The
mechanism of the failures is therefore invisible in the logs; only the successful resets can be read
back. That is why `reboot=c`, `reboot=t` and `reboot=e` all looked like "same failure".

### Every reset this machine has completed, with its mechanism

| Boot | Preceded by | Reason |
|---|---|---|
| −3 (Nov 18 23:35:57) | firmware save&reset (optimised defaults loaded) | `0x00080800` **CF9** ✓ POSTed |
| −2 (Nov 19 14:26:39) | power-on | `0x00200800` |
| −1 (Nov 19 21:06:43) | firmware save&reset (Fast Boot disabled) | `0x00080800` **CF9** ✓ POSTed |
| 0 (Nov 19 21:12:29) | **OS reboot via logind (Vicinae)** | `0x00080800` **CF9** ✓ POSTed |

So: firmware resets are CF9 writes, and the one OS-initiated reboot that ever completed POST was
**also a CF9 write**. `/sys/kernel/reboot/type` on the working system reads **`acpi`** — meaning the
kernel used the ACPI FADT `RESET_REG`, which on this board is the CF9 register with value `0x06`.

Timeline of that reboot (boot −1 → 0): `systemd-logind: The system will reboot now!` at 21:11:13,
POST, then boot 0 at 21:12:29 — a 75-second cycle. amdgpu was loaded (176.9 s into boot −1) before
the reboot, so the GPU was initialised and the reset still worked.

### The experiment this opens

Set the reboot type at runtime and see whether the mechanism is the variable:

```bash
cat /sys/kernel/reboot/type                  # acpi on the working system
sudo sh -c 'echo efi > /sys/kernel/reboot/type'
sudo reboot
```

- **`efi` hangs** → the reset mechanism *is* the variable, EFI `ResetSystem()` is the broken path,
  and the fix is one line: `reboot=a` in the boot entry (persist ACPI/CF9 explicitly). This would
  also explain why the firmware's own reset always worked and the OS's never did.
- **`efi` works** → the mechanism is not the variable; the NVRAM reset (optimised defaults) is the
  likely fix, and the config is simply "clean NVRAM".

Either way the next question is reproducibility: `sudo reboot` two or three times in a row, since a
single success has already been misleading once (2026-11-16).

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

### Two distinct failure modes — and Caps Lock tells them apart (2026-11-18)

The two look identical on screen (black, no logo) but are different faults:

| | Mode A — warm reset | Mode B — blank display |
|---|---|---|
| Trigger so far | any OS-requested reset | a power-on |
| Q-LEDs | none lit | not recorded for this event |
| **Caps Lock** | **dead** | **responds** |
| Fans | spinning | spinning |
| Was Linux running? | no (POST never started) | **no — no Linux boot exists in the journal for that window** |
| Meaning | board powered but POST never starts (EC/sequencing) | **firmware runs, its display output never comes up** |
| Family | this document | issue #11 blank-start; firmware-side, not `amdgpu` |

Observation 2026-11-18 (Mode B): the power-on after the failed `rtcwake` produced no display while
Caps Lock responded. `journalctl --list-boots` has **no Linux boot in that window at all** (see the
timeline below), so the machine was sitting in firmware — most likely in BIOS setup, since Del had
been pressed. Caps Lock responding is therefore the firmware's keyboard handling, not an OS.

That sharpens Mode B considerably: it is **not** the `amdgpu` driver and **not** the OS. It is the
firmware's own display initialisation (GOP / GPU VBIOS output path) failing on that power-on, and it
is reproducible with no Linux involved. Testable: on the next blank screen, try the other GPU output
(DisplayPort vs HDMI) and the motherboard's own video output (the iGPU is now `Auto`).

### Timeline of the 2026-11-18 rtcwake episode (from `journalctl --list-boots`, CET)

Boot entries only exist for boots that reached Linux, so the gaps carry the information:

| Boot | Start | End |
|---|---|---|
| −3 | 13:05:02 | 23:03:06 |
| −2 | 23:09:15 | 23:14:08 |
| −1 | 23:16:07 | 23:25:18 |
| 0 | 23:35:57 | — |

- **`-s 60` success** = the −2 → −1 gap (1 m 59 s: shutdown, alarm, POST, kernel start). Plausible.
- **`-s 20` attempt** = the shutdown at 23:25:18. The next Linux boot is **23:35:57 — 10 m 39 s
  later**, and that gap is the BIOS/defaults session (export header 22:33 UTC = 23:33 CET, saved
  just before boot 0). **No Linux boot exists near 23:25:38**, where the alarm would have fired.

User observation for that attempt: the **blue power LED was off** — the case light that shows whether
the desktop is powered, independent of Linux. It was not the green Q-LED; the blue power LED means
the machine was **not powered at all**.

**Conclusion: `rtcwake -m off -s 20` genuinely failed — the board stayed off.** The alarm either
never fired or was cleared/ignored, which fits the timing: 20 s can elapse while the kernel is still
shutting down. The earlier "the wake may have powered the board without POSTing" reading is
**withdrawn** — it was based on misreading the blue power LED as the green BOOT Q-LED. There is
therefore no evidence that a power-on can fail to POST; the widened hypothesis does not stand.

Practical outcome: **use `sudo rtcwake -m off -s 60`**, which is confirmed working. Verify any future
wake by the **blue power LED** (machine on) and then by the Q-LEDs (POST ran).

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

Workaround that does not depend on any of the above: `sudo rtcwake -m off -s 20` (real S5 poweroff
plus RTC wake = the cold boot that always works, scriptable in one command). **Verified working
2026-11-18 with `-s 60`; `-s 20` then appeared to fail** (see Mode B above — the wake may have
happened with no display). Use 45–60 s until the timing is settled: the alarm must not fire
mid-shutdown or it can be missed and the machine stays off. `Power On By RTC` is **Disabled in the
BIOS baseline and in the optimised-defaults export, yet the wake worked**, so that setting is not
the gate on this firmware — an earlier note here claiming it was is wrong. `ErP Ready` is Disabled.

Record for every attempt: logo yes/no, Caps Lock alive yes/no, Q-LED state, and afterwards
`journalctl -k -b -o short-monotonic | grep -m1 'Previous system reset'`.
