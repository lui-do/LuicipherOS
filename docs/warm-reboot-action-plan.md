# Warm-reboot action plan — session runbook

Runbook for the warm-reboot POST hang. Evidence and reasoning live in
`docs/warm-reboot-post-hang.md`; this file is *what to do, in order*.

**Ground rules**

- One variable per step. Write down the result of each step before starting the next.
- Recovery first. A failed first power-on after a forced button-off is **expected**, not a new fault.
- Do not re-run `reboot=` mechanism tests; that branch is closed (`efi`, `triple`, `cf9` all failed).
- Record with the **board**, not the screen: blue power LED (on/off) → Q-LEDs (red/yellow/white/green)
  → Caps Lock (dead/alive) → then the picture. A black screen is not proof the machine is dead.

---

## Recovery card

```text
1. Desktop still responds:   sudo poweroff        → press power once
2. Machine is stuck:         unplug the PSU cable → hold the power button 20–30 s
                             → plug back in → press power once
3. First power-on dead:      repeat step 2 once (expected, not a fault)
```

Why the long hold: with the cable out there is no mains power, so holding the button starts nothing —
it drains the capacitors. That is what the EC needs to forget the bad state.

---

## What we know (one screen)

| Reset requested by the OS | Result |
|---|---|
| default (EFI `ResetSystem`) | hang |
| `reboot=t` (triple fault) | hang |
| `reboot=c` (KBC "cold" hint) | no effect (mode hint, not a mechanism) |
| `reboot=p` / `cf9_force` (CF9 hard reset) | no reset observed |
| **reset requested by firmware (exit setup)** | **POSTs fine** ← the only warm reset that ever worked |

| Other lever | Result |
|---|---|
| boot entry (archinstall vs hand-written) | both hang |
| `amdgpu-unload-on-shutdown` enabled / disabled | both hang |
| MCR off (BIOS) | no effect |
| EXPO / memory | off, tested, clean |
| Q-LEDs during a hang | **none lit** → POST never starts |
| Fans during a hang | spinning → board is powered |

Current read: the board is powered but never begins POST after an OS-requested reset. Firmware's own
reset works. Suspects: EC / power sequencing, EC firmware (BIOS 4004, a beta).

---

## Step 0 — Clean the boot entry (2 min, no reboot)

The entry still carries `reboot=e` from the last experiment.

```bash
sudo cp /boot/loader/entries/2026-10-04_17-11-07_linux.conf.bak \
        /boot/loader/entries/2026-10-04_17-11-07_linux.conf
sudo grep '^options' /boot/loader/entries/2026-10-04_17-11-07_linux.conf
```

Expected: one `options` line ending in `amdgpu.runpm=0`, with no `reboot=` anywhere.

---

## Step 1 — Restore the one BIOS setting that matters (5 min)

Optimised defaults changed only two things; only one of them needs fixing.

1. Boot, press **Del** to enter BIOS setup.
2. **`Fast Boot` → Disabled.** (Defaults set it Enabled; it skips POST stages and shortens the
   window to press Del — bad on a board whose POST you are trying to watch.)
3. **Leave `Integrated Graphics` on `Auto`.** It gives you a second display output for Step 3.
4. Press **F10** → *Save Changes & Reset* → confirm.

This save-and-reset is itself a data point: if the machine POSTs here, firmware's own reset works
again (expected). Record it.

**Record:** `save&reset POST: ok / not ok`.

---

## Step 2 — The warm-reboot test (5 min) — **the main event**

This is the test Step 2 of the old plan existed for and it has not been run yet. With stale NVRAM
now wiped, it is a clean experiment.

```bash
sudo reboot
```

Watch and record **before touching anything**:

| Watch | Value |
|---|---|
| Blue power LED | on / off |
| Q-LEDs | which one lit, or none |
| Caps Lock | dead / alive |
| ASUS splash | yes / no |
| Boot menu | yes / no |

If it hangs: recover with the card, then get the receipt:

```bash
sudo journalctl -k -b -1 --no-pager | grep -m1 'Previous system reset'
```

### RESULT 2026-11-19: **the warm reboot WORKED** — and the log says how

`sudo reboot` from boot −1 completed: Q-LEDs (amber → red → white → green), TUF splash, boot menu,
LUKS prompt. The reset reason reported afterwards:

```
[0x00080800]: software wrote 0x6 to reset control register 0xCF9
```

That is the **ACPI FADT hard reset** (CF9). `/sys/kernel/reboot/type` reads **`acpi`**. Every reset
this board has ever completed — including both firmware save&resets — was a CF9 write.

Also from the journal: the reboot was `systemd-logind: The system will reboot now!`, i.e. a genuine
OS-initiated reboot, and amdgpu had been loaded 176 s into that boot, so the GPU was initialised.

**Consequence: stale NVRAM is a live suspect, not ruled out.** The optimised defaults were loaded
immediately before the first working reset, and nothing else changed.

### Next: two experiments, in this order

**A — reproducibility (5 min).** One success has already been misleading once (2026-11-16). Two
Vicinae reboots have now succeeded on 2026-11-19 (21:12:29 and 21:32:12, both `0x00080800` CF9), so
run the CLI path too, for confidence that the tool does not matter:

```bash
sudo reboot        # repeat 2–3 times
```

All POST → the configuration works; go to B to find out *why*.
Any hang → it is intermittent; B still applies.

Note: `/usr/bin/reboot` is a symlink to `systemctl`, so `sudo reboot` and the Vicinae button are the
same path (systemctl → logind → `reboot(2)`). The tool is not a variable.

**B — is the reset mechanism the variable? (5 min)**

```bash
cat /sys/kernel/reboot/type                                   # expect: acpi
sudo sh -c 'echo efi > /sys/kernel/reboot/type'
cat /sys/kernel/reboot/type                                   # expect: efi
sudo reboot
```

| Result | Meaning | Action |
|---|---|---|
| `efi` **hangs** | EFI `ResetSystem()` is the broken path; ACPI/CF9 is the working one | persist `reboot=a` in the boot entry (needs approval; validate with the `/proc/cmdline` receipt) |
| `efi` **works** | mechanism irrelevant; the NVRAM reset fixed it | document "clean NVRAM" as the fix, drop the reboot param |

The setting does not survive a reboot — set it again per attempt, or persist `reboot=a` in the entry.

### What the display problem is (a separate fault)

On 2026-11-19 several boots reached the LUKS prompt with **no video at all** — the passphrase had to
be typed blind, and it worked. From the journal:

- The console during the LUKS prompt comes from the **firmware framebuffer** (`simpledrm`/`efifb`).
  `simpledrm` initialises very late here — 24 s, 56 s and 161 s across three boots — so on some boots
  there is nothing on screen yet while the prompt waits.
- `amdgpu` is blacklisted, so nothing takes over until `amdgpu-late` runs at ~176–208 s.
- The motherboard-HDMI test was **inconclusive**: the iGPU (`card0`, `0000:0e:00.0`) only has a
  driver once `amdgpu` loads, and firmware drives the *primary* video device — the discrete card.

So the blank prompt is a **firmware / early-boot display handoff** problem, not `amdgpu` and not the
OS console. Different fault from the POST hang; Caps Lock still distinguishes them.

**Record:** `warm reboot after defaults: splash / menu / nothing — Q-LED: … — Caps Lock: …`.

---

## Step 3 — Display-output test (10 min) — for the blank-display fault

Only needed if you get a **black screen while the machine is alive** (Caps Lock responds). That
fault is firmware-side: on 2026-11-18 it happened with **no Linux running at all**.

When it happens — or proactively, once — try in this order and note which produces a picture:

1. **DisplayPort instead of HDMI** on the 7900 XT.
2. **The motherboard's own video output** (iGPU is now `Auto`).
3. **Monitor-only power cycle** (switch the monitor off and on).

Also record what the monitor itself says: **"no signal"** vs a live black picture. "No signal" means
the GPU never brought its output up.

**Record:** `blank screen: HDMI / DP / iGPU — monitor says: no signal / black`.

---

## Step 4 — Confirm the restart command (5 min)

`rtcwake -m off -s 60` is confirmed working; `-s 20` failed (the board stayed off — the blue power
LED was dark). Use 60 s.

```bash
sudo rtcwake -m off -s 60
```

Then **watch for 3 minutes without touching anything**, judged by the board:

| What you see | Meaning |
|---|---|
| Blue power LED on, Q-LEDs cycle | wake works — keep `-s 60`, move on |
| Blue power LED on, no Q-LED | board powered without POSTing — report immediately |
| Nothing at all | alarm not waking from S5 — use `poweroff` + button |

**Record:** `rtcwake 60: powered on yes/no — Q-LEDs cycled yes/no`.

---

## Step 5 — Re-flash the BIOS (30 min) — **requires explicit approval**

**Why:** the EC firmware ships inside the BIOS image, and a corrupted EC image survives every power
cycle. There is no newer BIOS than 4004 (already a beta, AGESA ComboAM5 PI 1.3.0.1d).

| Option | How | Notes |
|---|---|---|
| Re-flash **4004** (same version) | ASUS support → download → rename to `A5690.CAP` if needed → FAT32 USB → BIOS → Tool → ASUS EZ Flash 3 | Rewrites EC/AGESA, version unchanged |
| Downgrade to **3881** (last non-beta) | same procedure | AMD anti-rollback may refuse — record the outcome either way |

Then run one `sudo reboot` test and record it.

---

## Step 6 — Warranty case

Once Step 5 fails, nothing else is reachable by a user. The claim sentence:

> *After any reset — OS ACPI, EFI `ResetSystem()`, CF9, or CPU triple fault — the board remains
> powered (fans spinning, 12 V present) but produces no Q-LED activity and never starts POST. Only
> full removal of AC power restores it. A reset requested by the firmware itself (exiting BIOS setup)
> works normally. Reproducible on demand; independent of the OS, the boot entry and the installed
> devices. The board runs the newest firmware available (4004, a beta, AGESA ComboAM5 PI 1.3.0.1d).*

Target: **motherboard**. The GPU is not implicated in the POST hang; the PSU delivers power.

---

## Record sheet for tomorrow

```text
Step 0 entry cleaned:            yes/no
Step 1 Fast Boot -> Disabled:    yes/no    save&reset POST: ok/not ok
Step 2 sudo reboot:              splash/menu/nothing
       Q-LED:                    none/red/yellow/white/green
       Caps Lock:                dead/alive
       power LED:                on/off
Step 3 blank screen (if any):    HDMI/DP/iGPU    monitor: no signal/black
Step 4 rtcwake -s 60:            powered on yes/no    Q-LEDs cycled yes/no
Step 5 BIOS re-flash:            done/skipped    result:
```

### Result sheet 2026-11-19 (filled)

```text
Step 0 entry cleaned:            yes   (/proc/cmdline has no reboot=)
Step 1 Fast Boot -> Disabled:    yes   save&reset POST: ok (LUKS prompt visible)
Step 2 sudo reboot (via Vicinae): SPLASH + MENU + LUKS PROMPT  <-- WORKED
       Q-LED:                    amber -> red -> white -> green
       reset reason:             0x00080800 = CF9 write (ACPI hard reset)
       reboot type:              acpi
       logind:                   "The system will reboot now!"
Step 3 blank screen:             yes, on earlier boots — typed LUKS blind; iGPU HDMI also dark
                                 (iGPU test inconclusive: no driver until amdgpu loads)
Step 4 rtcwake -s 60:            worked 2026-11-18; -s 20 fails (alarm missed)
Step 5 BIOS re-flash:            not yet
```

---

## Already ruled out (do not re-test)

| Hypothesis | How it died |
|---|---|
| Boot entry / kernel params | both entries hang; params verified applied via `journalctl -k -b -1` |
| GPU driver unload timing at shutdown | hangs with the unload unit enabled *and* disabled |
| `reboot=c` (KBC "cold") | a mode hint, not a mechanism — no-op |
| `reboot=t` (triple fault) | hang (CPU-only reset, EC never notified) |
| `reboot=e` / default (EFI `ResetSystem`) | hang — this is what every earlier attempt used |
| `pci` (CF9 hard reset) | no reset observed |
| GPU / memory / boot device as cause of the hang | POST never starts, so no device is initialised |
| PSU as a supply fault | rails present (fans spinning) during the dead state |
| Stale NVRAM / CMOS | **live suspect** — optimised defaults loaded 2026-11-18, and the first working reset came immediately after |
| Reset mechanism | **reopened** — the one OS reboot that worked used ACPI/CF9; EFI `ResetSystem()` has never been confirmed to work. See Step 2B |
| `rtcwake -s 20` | too short — the alarm is missed; use `-s 60` |
