# Office suite comparison for LuicipherOS

Date: 2026-09-30. Constraints from `CONTEXT.md` + `config/packages*`: Arch-based,
declarative lists, **Extra > Flatpak > AUR-bin**, tiny AUR surface (soname-breakage
trauma), 8 GB RAM floor machines in scope. Printer stack (CUPS/Gutenprint) already
in `config/packages`; suite choice is the open item (line 79-80).

No `config/*` desired-list files were touched by this research. No commit made.

## Scoring axes (maintainer's four + packaging + privacy)

1. **RAM** on 8 GB machines (official floors + runtime architecture)
2. **OOXML round-trip fidelity** (.docx/.xlsx/.pptx with MS Office users)
3. **Plugin/extension support**
4. **UI customization / theming** (dark mode, Wayland-native on Hyprland)
5. **Packaging reality on Arch** (repo, size, update cadence)
6. **Telemetry / privacy**

Head-to-head idle-RSS benchmarks were NOT measured; RAM scores below use vendors'
published minimums plus architecture. Suggested follow-up: open the same 3 .docx
files in each finalist on the target machine and record `systemd-cgls` RSS.

## Candidates

### 1. LibreOffice (Fresh) — RECOMMENDED DEFAULT

- **Packaging:** `Extra/libreoffice-fresh` **26.8.0-2**, updated 2026-08-28,
  maintainer Andreas Radke. 148 MB package / 423 MB installed. Zero AUR surface —
  the only candidate that fits `config/packages` directly and tracks Arch rolling.
  `libreoffice-still` exists as a conservative alternative branch.
- **RAM:** Official floor **256 MB (512 MB recommended)** — the lightest published
  floor of any full suite. Native C++.
- **OOXML:** Compatible with Microsoft Office (365); imports/exports OOXML plus ODF
  natively. Fidelity is good but not perfect — complex .docx/.pptx layouts can
  shift. Full suite: Writer, Calc, Impress, **Draw, Base, Math** (no rival ships
  the last three).
- **Plugins:** Richest ecosystem: extensions.libreoffice.org, in-app Extension
  Manager, packaged extensions in Extra (`libreoffice-extension-texmaths`,
  `libreoffice-extension-writer2latex`), macros in Basic/Python/JS, `-sdk` split
  package, `--headless --convert-to` for scripted conversion.
- **Theming/Wayland:** VCL backends `gtk3`/`gtk4`/`qt6` auto-detected, forced via
  `SAL_USE_VCLPLUGIN`; follows system GTK/Qt theme incl. dark; KF6 integration via
  optional `kio` dep. Wayland works with caveats: a known scroll-lag bug under
  Plasma/GNOME Wayland (workarounds: `SAL_USE_VCLPLUGIN=gtk3` or Xwayland flags).
  On Hyprland this is manageable and documented.
- **Privacy:** Backed by non-profit The Document Foundation; offline by default,
  no account, no ad network.
- **Flatpak fallback:** `org.libreoffice.LibreOffice`, ~312 MiB download.

### 2. ONLYOFFICE DesktopEditors — RUNNER-UP (opt-in for OOXML-heavy users)

- **Packaging:** **AUR only** (`onlyoffice-bin` 9.4.0-1, updated 2026-05-19,
  maintainer dbermond, 306 votes, AGPL-3.0-only). It is a **prebuilt** repack of
  the official .deb from GitHub releases — satisfies the `-bin`-over-source rule
  (no compile, no OOM risk) — but still +1 AUR surface that can lag and break on
  soname bumps. **Not in Extra.**
- **RAM:** Official floor **2 GB RAM**, dual-core 2 GHz — 4-8x LibreOffice's
  published floor. Chromium-assisted editors; heaviest runtime here. Fine on the
  8 GB floor, least headroom of the shortlist.
- **OOXML:** **Best in class.** OOXML (.docx/.xlsx/.pptx) is its *native* format,
  so round-trips with MS Office users are the most faithful. This is its reason
  to exist alongside LibreOffice.
- **Plugins:** Real Plugin Marketplace (since v7.4): one-click install via Plugin
  Manager or manual `.plugin` drop into `sdkjs-plugins/`; JS plugin API; AI
  integration (local or cloud models); PDF forms + e-signatures.
- **Theming/Wayland:** Tabbed UI with switchable interface themes incl. dark.
  Qt-based; Wayland runs but with papercuts (AUR comments: XWayland behavior,
  `QT_QPA_PLATFORM` issues; xdg-desktop-portal file picker needs a
  `--xdg-desktop-portal=default` flag).
- **Privacy:** AGPL open source, works fully offline; optional cloud connect
  (Nextcloud/ownCloud/Seafile). No ad/telemetry model.
- **Flatpak fallback:** `org.onlyoffice.desktopeditors`, **~587 MiB** download —
  nearly 2x LibreOffice's Flatpak; community notes it trails native releases.
- **Fit:** Recommend as documented opt-in (AUR or Flatpak-user list) for users who
  live in .docx review cycles, not as the default — keeps the default image
  Extra-clean.

### 3. WPS Office — REJECT (privacy + staleness + security)

- **Packaging:** **AUR only** (`wps-office` 11.1.0.11723-2, **last updated
  2025-05-02 — stale > 1 yr**). Proprietary `LicenseRef-WPS-EULA`. International
  Linux builds are stuck at 11.x; v12+ exists only as `wps-office-cn` (per AUR
  maintainer pinned comment). Upstream URL (`wps-community.org`) was observed
  hijacked to spam (multiple AUR comments, 2026) — maintenance smell. Needs
  *companion* AUR packages in practice (`freetype2-wps` for the fakebold bug,
  `libtiff5` for PDF, `ttf-wps-fonts`) — the opposite of a tiny AUR surface.
  ArchWiki additionally documents mime-hijacking and EN/CN-only official UI.
- **RAM:** Light and fast (native, runs well on decade-old netbooks) — its one
  technical merit for the 8 GB floor.
- **OOXML:** Excellent fidelity, MS-lookalike UI. Not disputed — just not worth
  the price below.
- **Plugins:** Thin/skins-and-templates story; no marketplace comparable to the
  two finalists.
- **Theming/Wayland:** Skinnable but X11-era; XWayland on Hyprland, no native
  Wayland/dark integration story.
- **Privacy — disqualifying:** Proprietary client whose current privacy policy
  (2025-08-15) describes collection of log data, device identifiers, ad IDs, and
  sharing with **ad providers and SDK vendors**. Community hardening practice is
  to firewall it entirely (Pi-Apps ships it `firejail --net=none`). Separately,
  **CVE-2024-7262 / CVE-2024-7263**: a WPS zero-day exploited in the wild by
  APT-C-60 (ESET), which Kingsoft initially patched silently and incompletely.
  Closed binary + ad-tech data flows + exploited zero-day history = incompatible
  with a privacy-sane default.

### 4. Calligra — REJECT as default (alive, but wrong tradeoffs)

- **Status (it is alive):** Calligra 4.0 released 2024-08-27 (Qt6/KF6 port, UI
  overhaul); Arch `Extra/calligra` **26.08.1-1**, updated 2026-09-10, on KDE Gear
  cadence. 39 MB / 116 MB installed — smallest full-suite footprint. GPL.
- **Why not:** ODF-native with historically the **weakest OOXML round-trip**
  (the 3.2 release notes even document Sheets crashing on LO-generated files);
  Words/Sheets/Stage only at full support (Kexi/Plan on separate schedules);
  negligible plugin ecosystem; and on Hyprland/GTK LuicipherOS it drags a KDE
  Frameworks dependency tail for no fidelity gain. Interesting only for Qt
  purists — not a default.

### 5. GNOME Office pieces (AbiWord / Gnumeric) — REJECT as suite

- There is **no GNOME Office suite**: the 2003 "1.0" was a meta-package label, and
  current GNOME has no word processor/presentation story (2025 revival essay
  proposes building new libadwaita apps, possibly around `Letters`/Pandoc —
  pre-proposal, not shippable).
- `Extra/abiword` 3.0.8-2 (5 MB) is effectively dormant: abisource.com dead since
  ~2023, GTK3, only build-fix commits on GNOME GitLab. `Extra/gnumeric` 1.12.62-1
  (13 MB, GTK3) is maintained but is a **spreadsheet only** — no presentation,
  OOXML as second-class. Fine as niche opt-ins; not a suite answer.

## Scoreboard

| Criterion | LibreOffice Fresh | ONLYOFFICE | WPS | Calligra | GNOME pieces |
|---|---|---|---|---|---|
| RAM floor (published) | 256–512 MB ✅ | 2 GB ⚠️ | light ✅ | light ✅ | tiny ✅ |
| OOXML fidelity | good ⚠️ | **best** ✅ | excellent ✅ | weak ❌ | weak ❌ |
| Plugins | **richest** ✅ | marketplace ✅ | thin ❌ | ~none ❌ | per-app ⚠️ |
| Dark / Wayland-native | VCL gtk/qt + dark ✅ (Wayland caveats, documented) | themes + dark ⚠️ (Wayland papercuts) | skins / XWayland ⚠️ | Qt6 ✅ but KDE tail | GTK3, dated ⚠️ |
| Arch packaging | **Extra, current** ✅ | AUR-bin ⚠️ | AUR stale ❌ | Extra ✅ | Extra ✅ |
| Privacy | TDF non-profit ✅ | AGPL offline ✅ | ad-tech + CVEs ❌ | KDE ✅ | ✅ |

## Recommendation

- **Default: LibreOffice Fresh from Extra** (`libreoffice-fresh` + needed
  `libreoffice-fresh-*` lang packs; Java remains optional — needed only for Base
  wizards and some extensions). One line in `config/packages`, zero AUR growth,
  full suite incl. Draw/Base, prints through the existing CUPS stack.
- **Runner-up / opt-in: ONLYOFFICE DesktopEditors** via AUR `onlyoffice-bin`
  (or `flatpaks-user.list`) for users whose workflow is dominated by MS OOXML
  round-trips. Document both paths; do not preinstall.
- **Explicitly not shipped:** WPS (telemetry, proprietary, stale, CVE history),
  Calligra (fidelity/ecosystem), AbiWord/Gnumeric-as-suite (no suite exists).

## Primary sources

- Arch package pages: libreoffice-fresh 26.8.0-2 (Extra, 148.2/423.1 MB,
  2026-08-28); calligra 26.08.1-1 (Extra, 2026-09-10); gnumeric 1.12.62-1;
  abiword 3.0.8-2; AUR onlyoffice-bin 9.4.0-1 (2026-05-19, AGPL-3.0-only);
  AUR wps-office 11.1.0.11723-2 (2025-05-02, LicenseRef-WPS-EULA).
- ArchWiki: LibreOffice (VCL theming, extensions, Wayland troubleshooting);
  WPS Office (install, mime, fakebold/freetype2-wps, libtiff5, language limits).
- libreoffice.org: System Requirements (256/512 MB RAM); Discover LibreOffice
  (suite contents, MS 365 compat); extensions.libreoffice.org.
- helpcenter.onlyoffice.com: Desktop Editors for Linux system requirements
  (dual-core 2 GHz, 2 GB+); api.onlyoffice.com: desktop plugin install/marketplace.
- Flathub: org.libreoffice.LibreOffice (312 MiB); org.onlyoffice.desktopeditors
  9.4.0 (587 MiB, "fully compatible with Office Open XML").
- calligra.org: Calligra 4.0 announcement (2024-08-27, Qt6/KF6); components pages.
- wps.com Privacy Policy (updated 2025-08-15: log/device/ad-ID collection, ad
  partners, SDK sharing); SecurityWeek/ESET on CVE-2024-7262/7263 exploitation;
  pi-apps.io WPS page (ships firewalled, `firejail --net=none`).
- GNOME: AbiWord GitLab (World/AbiWord, build-fix-only history); guix Mirror
  thread on abisource.com death (~Aug 2023); It's FOSS GNOME Office revival essay
  (2025-11: no current suite, GTK3 status of AbiWord/Gnumeric).
