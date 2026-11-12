# Memory / BIOS single-variable test plan (2026-11)

**Goal:** determine whether memory instability — specifically EXPO — causes the CPU-level events in
issue #13: instant resets (`0x00800800`, "internal CPU shutdown event occurred") and the hard kernel
lockup of 2026-11-12 (Caps Lock dead, fans spinning, long-press power-off required).

**Machine:** ASUS TUF GAMING B650E-PLUS WIFI, BIOS 4004 (2026-09-16), Ryzen 5 9600X (family 0x1A),
~32 GB DDR5, RX 7900 XT.

**Rule for the whole plan: one change at a time.** Two changes at once makes the result meaningless.

---

## Phase 1 — MemTest86+ baseline (current settings, nothing changed)

Run the memory test **before touching the BIOS**, so it tests the machine exactly as it fails in
daily use.

- Media: MemTest86+ v9.00 USB (`MT86PLUS_64`). Report stick: 14.4 GB FAT32 (`MEMTEST`).
- Both sticks plugged in **before** boot. F8 at power-on → pick the `UEFI:` `MT86PLUS_64` entry.
- Duration: **minimum one full pass.** Two to three passes is a real test. Overnight gives
  confidence. A partial pass proves nothing.
- **Press F6 while the screen is visible** to save the report to the `MEMTEST` stick. If it reports
  `No FAT32 filesystem found`, photograph the screen instead.
- Record: elapsed time, pass count, **the memory speed displayed**, error count and addresses,
  and whether any module is flagged `BAD CRC!`.

### Decision rule

**Any error** — memory is unstable at current settings, and EXPO is the prime suspect.
**Disable EXPO immediately** (`Ai Overclock Tuner` -> `Auto`), then re-run MemTest86 to confirm.

**Clean after a long run** — memory is probably stable at EXPO speed, so EXPO is *not* the cause.
Record the baseline in Phase 2, then work down the suspect list starting at #2.

An error in the **first pass is already a complete answer** — stop and act on it.

---

## Phase 2 — BIOS baseline (record before changing anything)

Enter BIOS with **DEL** (press **F7** for Advanced Mode). Photograph these before touching them —
otherwise there is no way back and no way to tell what changed.

| Setting | Where (paths vary by BIOS version) | Current value |
| --- | --- | --- |
| **Ai Overclock Tuner** | `Ai Tweaker` | ______________ |
| **DRAM Frequency** | `Ai Tweaker` | ______________ |
| **Precision Boost Overdrive** | `Ai Tweaker` | ______________ |
| **Curve Optimizer** | `Ai Tweaker` (under PBO) | ______________ |
| **Memory Context Restore** | `Ai Tweaker` → `DRAM Timing Control` | ______________ |
| **Power Supply Idle Control** | `Advanced` → `AMD CBS` → `CPU Common Options` | ______________ |
| **SoC voltage** | `Ai Tweaker` → voltage section | ______________ |

The BIOS has a **search function** (usually F9 in Advanced Mode) which is faster than hunting menus.

---

## Phase 3 — Suspects, in order, one at a time

Each row is a separate experiment: make the change, then run the machine normally for several days
and watch for a lockup or reset. Only then move to the next row.

| # | Setting | Change to | Why |
| --- | --- | --- | --- |
| 1 | **Ai Overclock Tuner** | `Auto` | Disables EXPO. The primary test. |
| 2 | **Memory Context Restore** | `Disabled` | Known AM5 instability source. |
| 3 | **Precision Boost Overdrive** | `Auto` | CPU overclocking; a source of instability. |
| 4 | **Curve Optimizer** | `Disabled` | **Top suspect if enabled** (see below). |
| 5 | **Power Supply Idle Control** | `Typical Current Idle` | Classic AM5/AM4 idle-lockup fix. |
| 6 | **SoC voltage** | observe only | Note if above ~1.30 V; do not change. |

On row 4: an aggressive negative Curve Optimizer offset causes exactly the observed pattern —
crashing at idle and light load. If it is enabled, treat it as the leading suspect.

If Phase 1 was **clean**, skip #1 and start at #2 (and answer the PBO/Curve Optimizer question
first — those are the strongest remaining candidates for light-load lockups).

If every row above is exhausted and the fault continues, the next step is **PSU swap** (issue #13).

---

## What to record each time

Before every shutdown, by hand (DPMS state is invisible to the journal):

```
date; uptime          →  then one word:  clean  |  stalled
```

And for each lockup or reset: the time, what was running, whether the screen was frozen or black,
whether Caps Lock toggled, and how the machine was powered off.

---

## Safety notes

- **Turn off the monitor only, never the PC.** The PC is on the wall socket; the monitor is on the
  power strip.
- **Never press ESC in MemTest86** — it stops the test. If the screen is black in the morning, wait
  ~20 s, then power-cycle the monitor.
- `dd` and disk commands: **re-check `lsblk` every time.** Device letters shift as sticks are added
  and removed — the MemTest86 stick has already been `sda` and `sdc` in the same session.
- The LuicipherOS netinstall stick was formatted for this test. Its image is backed up at
  **`/home/work/luici-installer-backup.img`** (2 GB, verified: `LABEL="LUICI_202610"`, both
  partitions present). Restore with:
  `sudo dd if=/home/work/luici-installer-backup.img of=/dev/sdX bs=4M status=progress conv=fsync`

## Related

- Issue #13 — the CPU-level events this plan is trying to explain.
- `.agent/CONTINUITY.md` — full evidence, reset-reason census, and the 2026-11-12 lockup forensics.
