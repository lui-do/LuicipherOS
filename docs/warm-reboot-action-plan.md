# Warm-reboot action plan — next hands-on session

Runbook for the warm-reboot POST hang. Findings and evidence live in
`docs/warm-reboot-post-hang.md`; this file is just *what to do, in order*.

**Current state:** the board stays powered after any reset (fans spinning, 12 V present) but never
starts POST — no Q-LED lights at all. Only a full collapse of the power rails brings it back.
Everything OS-side has been ruled out. Remaining suspects: EC / power sequencing, EC firmware, and
to a lesser degree stale CMOS/NVRAM state.

**Ground rules**

- One variable per step. Record the result of each step before starting the next.
- Recovery first: if anything goes wrong, the recovery below is the answer, and it has never failed.
- A failed first power-on after a forced button-off is **expected**, not a new fault. Retry once.
- Do not re-run `reboot=` mechanism tests; that branch is closed.

---

## Recovery card (use whenever the machine is stuck)

```text
1. If the desktop still responds:  sudo poweroff     → press power
2. If it is stuck:      unplug the PSU cable → hold the power button 20–30 s
                        → plug the cable back in → press power once
3. If the first power-on shows nothing: unplug again, repeat step 2 once
```

Why the long hold: with the cable out there is no mains power, so holding the button does not start
anything — it drains the capacitors. That is what the EC needs to forget the bad state.

---

## Step 0 — Clean the boot entry (2 min, no reboot)

The entry still carries `reboot=e` from the last experiment.

```bash
sudo cp /boot/loader/entries/2026-10-04_17-11-07_linux.conf.bak \
        /boot/loader/entries/2026-10-04_17-11-07_linux.conf
sudo grep '^options' /boot/loader/entries/2026-10-04_17-11-07_linux.conf
```

Expected: one `options` line, ending in `amdgpu.runpm=0`, with no `reboot=` anywhere.
Nothing to test — the next boot picks it up.

---

## Step 1 — Learn the recovery, and get a one-command restart (15 min)

**Why this step exists.** Everything after this depends on being able to bring the machine back
without drama. Until now the recovery has been improvised, and on 2026-11-18 a forced button-off
was followed by one dead power-on before the next one worked. We need to know that this is normal
behaviour of a stuck board and not a new fault — otherwise every later result gets muddied.

### 1A — Practise the recovery, twice

Do this exactly, and count the seconds out loud the first time:

1. In the desktop, run `sudo poweroff`. Wait until everything is silent — fans stopped, no lights.
2. **Unplug the power cable from the wall socket** (or flip the PSU switch to O).
3. Press and hold the case power button for **20–30 seconds**. Nothing happens on screen; that is
   correct. Keep holding.
4. Plug the cable back in (PSU switch to I).
5. Press the power button **once**, briefly.
6. Expect: ASUS/TUF splash, then the boot menu, then the system boots.
7. Write down whether it worked first try. Then repeat 1–6 once more and write that down too.

**Record:** `cycle 1: first try / needed a second attempt` — `cycle 2: first try / needed a second attempt`.

If both cycles boot first try, the recovery is solid and everything else can proceed.

**Result 2026-11-18: recovery practised, RTC wake confirmed working.** The machine shut down and
powered itself back on to the boot menu. So the workaround is real: `rtcwake` gives a one-command
restart that uses the only condition this board handles reliably (a clean S5, rails collapsed).

### 1B — Test a one-command restart (optional but recommended)

Goal: turn "shutdown + press the button" into a single command, so the machine is comfortable to
use while this is unfixed.

```bash
sudo rtcwake -m off -s 20
```

What this does: it sets an alarm 20 seconds ahead, then switches the machine off **completely**
(same as a normal shutdown — the rails collapse, which is the part the board needs), and the board's
clock switches it back on by itself. Nothing else to run; the terminal dies with the machine.

**On the delay:** `-s` is the wait in seconds, and it has to be long enough for the system to
actually finish reaching S5 — if the alarm fires mid-shutdown it can be missed and the machine
stays off. 15–20 s is the practical floor on this machine; 60 s is unnecessarily generous. Test
`20` first and step it down if you want it tighter.

- **Comes back by itself** → you now have a safe restart command. From now on:
  `sudo rtcwake -m off -s 20` instead of `sudo reboot`. (A `lui` subcommand can wrap this later.)
- **Stays off** → press the power button, note "RTC wake does not work here", and we drop the idea.
  The BIOS setting behind it is `Advanced → APM Configuration → Power On By RTC`.

**Record:** `rtcwake: came back / stayed off`.

---

## Step 2 — Reset BIOS settings from inside setup, then one reboot test (25 min)

**Why:** the failure is the board never starting POST, which is EC/NVRAM territory. Loading
optimised defaults from inside setup wipes stale NVRAM settings without opening the case, and
because saving in setup also resets the platform, it doubles as a firmware-driven reset test.

1. Boot, press **Del** to enter BIOS setup.
2. Press **F5** → *Load Optimized Defaults* → accept.
3. Press **F10** → *Save Changes & Reset* (or *Save Changes and Exit*) → confirm.
   *Expected:* the machine resets and POSTs normally (this path has worked before).
4. Boot into LuicipherOS with defaults. Note: EXPO is already off in the baseline, so this costs
   you nothing you were using.
5. Once at the desktop, one test: `sudo reboot`.
6. Record what happens: Q-LED lit? ASUS splash? boot menu? nothing?

**Record:** `defaults boot: ok / not ok` — `warm reboot after defaults: splash / menu / nothing`.

If the reboot POSTs — real finding, a stale setting was involved, and we diff against
`docs/bios-profiles/` to find which one. If it hangs — expected, continue to Step 3.

### Result 2026-11-18: defaults loaded; two settings changed

Export kept at `docs/bios-profiles/OPTIMISEDDEFAULTS_*`. Diff against the baseline is small:

| Setting | Baseline | After defaults | Action |
|---|---|---|---|
| `Fast Boot` | Disabled | **Enabled** | **set back to Disabled** — it skips POST stages, which is exactly what you need to watch on a board whose POST is fragile, and it shortens the window to press Del |
| `Integrated Graphics` | Disabled | **Auto** | decide: keep Disabled (match baseline) or keep Auto as a free diagnostic output |
| everything else | — | unchanged | `Power On By RTC` Disabled, `ErP` Disabled, Above 4G + ReBAR Enabled, IOMMU Auto, MCR Auto |

**The warm-reboot test after defaults has not been run yet** — that is the point of Step 2, so run
one `sudo reboot` and record it.

Note the iGPU is now available as a diagnostic: with `Integrated Graphics` Auto, the monitor can be
plugged into the motherboard's own video output. If a blank screen shows a picture there but not on
the 7900 XT, the fault is the discrete GPU's output; if both are blank, it is the platform. That is
a useful test for Mode B (see `docs/warm-reboot-post-hang.md`).

### Also outstanding from Step 1: settle the rtcwake timing

`-s 60` woke the machine; `-s 20` did not (the green BOOT Q-LED never lit, and no Linux boot appears
near the alarm time). `-s 20` is likely simply too short — the alarm can fire while the kernel is
still shutting down and be cleared or ignored.

```bash
sudo rtcwake -m off -s 60
```

Then **watch the board for 3 minutes without touching anything**, and record:

| Question | Why it matters |
|---|---|
| Do the Q-LEDs cycle (red → white → green)? | proves POST actually ran |
| Do the fans spin up? | proves the board was powered |
| Does the power LED come on? | proves the PSU got PS_ON# |
| Does the display ever come up? | separates Mode A (dead POST) from Mode B (alive, no picture) |

- Q-LEDs cycle → the wake works; keep `-s 60` and move on.
- Fans spin but no Q-LED → **the wake powered the board without POSTing** — the same fault as the
  warm reboot, and a much bigger finding. Report it.
- Nothing at all → the alarm is not waking this board from S5; use `sudo poweroff` + the button.

Do not judge a wake by the screen: on 2026-11-18 a black screen was briefly assumed to mean failure,
and the machine may in fact have been running.

Optional variant if Step 2 changes nothing and you want to go further: the hardware CMOS clear
(CLRTC pins with the PSU unplugged). Restore settings afterwards from `docs/bios-profiles/`.

---

## Step 3 — Re-flash the BIOS (30 min) — **requires explicit approval**

**Why:** the EC firmware ships inside the BIOS image, and a corrupted EC image survives every power
cycle — so this is the one intervention that has not been indirectly tested yet. There is no newer
BIOS than 4004 (it is already a beta, AGESA ComboAM5 PI 1.3.0.1d).

Options, in order of preference:

| Option | How | Notes |
|---|---|---|
| Re-flash **4004** (same version) | Download from ASUS support, rename to `A5690.CAP` if needed, copy to a FAT32 USB stick, BIOS → Tool → ASUS EZ Flash 3 | Rewrites EC/AGESA without changing version |
| Downgrade to **3881** (last non-beta) | same procedure | AMD anti-rollback may refuse it — that is a valid outcome, record it |

After flashing, run one `sudo reboot` test and record it.

---

## Step 4 — Warranty case

Once Steps 2 and 3 have failed, nothing else is reachable by a user. The claim sentence:

> *After any reset — OS ACPI, EFI `ResetSystem()`, CF9, or CPU triple fault — the board remains
> powered (fans spinning, 12 V present) but produces no Q-LED activity and never starts POST. Only
> full removal of AC power restores it. Reproducible on demand; independent of the OS, the boot
> entry and the installed devices. The board is on the newest firmware available (4004, a beta,
> AGESA ComboAM5 PI 1.3.0.1d).*

Target is the **motherboard**. The GPU is not implicated in this symptom, and the PSU delivers power
correctly.

---

## Already ruled out (do not re-test)

| Hypothesis | How it died |
|---|---|
| Boot entry / kernel params | both entries hang; params verified applied via `journalctl -k -b -1` |
| GPU driver unload timing at shutdown | hangs with the unload unit enabled *and* disabled |
| `reboot=c` (KBC "cold") | a mode hint, not a mechanism — no-op |
| `reboot=t` (triple fault) | hang (CPU-only reset, EC never notified) |
| `reboot=e` / default (EFI `ResetSystem`) | hang — this is what every earlier attempt used |
| `pci` (CF9 hard reset) | no visible reset, then a failed first power-on |
| GPU / memory / boot device as cause | POST never starts, so no device is initialised |
| PSU as a supply fault | rails present (fans spinning) during the dead state |
| Linux-side diagnostics worth repeating | — |
