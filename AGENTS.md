# AGENTS.md

## Agent skills

### Issue tracker

Issues tracked in GitHub Issues via `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical roles mapped 1:1 to label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout (`CONTEXT.md` + `docs/adr/`). See `docs/agents/domain.md`.

## archinstall field notes (verified 2026.09.01 ISO, VM smoke Sep 2026)

`install/archinstall-desktop.json` must satisfy the CURRENT archinstall
parser — older examples lie. Docs:

- Guided/config reference: https://archinstall.archlinux.page/
- Source of truth for schema: https://github.com/archlinux/archinstall/blob/master/archinstall/lib/models/device.py
- Man page (config sample): https://man.archlinux.org/man/archinstall.1.en

Strictness found the hard way (each was a failed install):

1. `size`/`start` need a `sector_size` OBJECT (`{"unit": "B", "value": 512}`),
   never `null` — else `TypeError` in `SectorSize.parse_args`.
2. `unit` comes from a fixed `Unit` enum (B/kB/MB/GB/… + KiB/MiB/GiB/… +
   `sectors`). There is NO `Percent` and NO fill-remaining-disk value —
   give the btrfs partition an explicit GiB size (EDIT-ME per disk;
   see issue #2 for the lsblk helper).
3. ESP detection needs the explicit `esp` flag (`flags: ["boot", "esp"]`
   on the fat32 partition) — `boot` alone is NOT recognized as ESP
   (`is_esp` checks `PartitionFlag.ESP`), installer aborts with
   "EFI system part ESP not found".
4. Keep `"silent": false` for first runs: the TUI opens prefilled so a
   human reviews disk/users before writing. Only automate unattended
   once the JSON is proven on that archinstall version.
