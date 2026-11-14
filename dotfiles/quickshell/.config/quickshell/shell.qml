// shell.qml — LuicipherOS custom Quickshell shell v0.1.
// A minimal top bar + plugin host. Plugins drop into plugins/ as single
// .qml files; enable them in plugins.json (load order).
//
// Configuration layering (shared base + per-user override):
//   1. inline defaults below            (fail-safe: shell works with no files)
//   2. tokens.json                      (base for ALL users — stow-managed, shared)
//   3. $XDG_CONFIG_HOME/luicipher/quickshell/tokens.json   (per-user, real file,
//      NEVER stow-managed, survives updates; e.g. a bigger bar: {"barHeight": 40})
// Later layers win key-by-key. Both files hot-reload on save (FileView watch).
//
// Written so widgets ported from Noctalia, DankMaterialShell, or Omarchy
// can slot in: each plugin gets bar height + palette via the `luci` object.
// v0.1 scope: clock + swaync indicator + plugin row. Workspaces widget,
// system tray, and notification center arrive in v0.2 (swaync covers
// notifications until then — see dotfiles/swaync).
import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ShellRoot {
    id: root

    // Layer 1: fail-safe defaults. The shell renders correctly even if both
    // token files are missing or malformed.
    readonly property var tokenDefaults: ({
        barHeight: 30,
        accent: "#89b4fa",
        bg: "#1e1e2e",
        fg: "#cdd6f4",
        muted: "#6c7086",
        fontFamily: "JetBrainsMono Nerd Font"
    })

    // Layers 2 + 3, filled from the FileViews below (empty object on any error).
    property var baseTokens: ({})
    property var userTokens: ({})

    // Shared tokens plugins read: luci.barHeight, luci.accent, ...
    // Recomputed automatically when either file changes.
    property var luci: Object.assign({}, root.tokenDefaults,
                                     root.baseTokens, root.userTokens)

    // Resolve $XDG_CONFIG_HOME without QtQuick.Config-style helpers; configPath
    // is deprecated and resolves relative to the shell dir, so build the path
    // from the environment explicitly.
    readonly property string userTokensPath:
        (Qt.environment("XDG_CONFIG_HOME") ||
         Qt.environment("HOME") + "/.config") + "/luicipher/quickshell/tokens.json"

    function parseTokens(text) {
        if (!text || !text.trim()) return ({})        // missing/empty file: silent
        try {
            const parsed = JSON.parse(text)
            return (parsed && typeof parsed === "object") ? parsed : ({})
        } catch (e) {
            console.warn("luicipher: bad tokens JSON ignored:", e.message)
            return ({})
        }
    }

    // Layer 2: shared base tokens (same directory as this file).
    FileView {
        id: baseTokensFile
        path: Qt.resolvedUrl("tokens.json").toString().replace("file://", "")
        watchChanges: true
        preload: true
        onLoaded: root.baseTokens = root.parseTokens(text)
        onFileChanged: root.baseTokens = root.parseTokens(text)
    }

    // Layer 3: this user's overrides. May not exist — handled silently.
    FileView {
        id: userTokensFile
        path: root.userTokensPath
        watchChanges: true
        preload: true
        onLoaded: root.userTokens = root.parseTokens(text)
        onFileChanged: root.userTokens = root.parseTokens(text)
    }

    // Enabled plugin file names, in load order (mirrors plugins.json).
    property var pluginNames: ["swayncIndicator"]

    PanelWindow {
        anchors { top: true; left: true; right: true }
        implicitHeight: root.luci.barHeight
        color: root.luci.bg

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 16

            Text {
                text: "LuicipherOS"
                color: root.luci.accent
                font.family: root.luci.fontFamily
                font.pointSize: 11
            }

            // Plugin row. `asynchronous: true` keeps instantiation off the
            // startup frame; `luci` is bound (not copied) so plugins follow
            // token hot-reloads. RAM rule (see README): plugins that live in
            // on-demand windows must gate on window visibility instead.
            Repeater {
                model: root.pluginNames
                Loader {
                    required property var modelData
                    source: Qt.resolvedUrl("plugins/" + modelData + ".qml")
                    asynchronous: true
                    onLoaded: {
                        if (item && item.hasOwnProperty("luci"))
                            item.luci = Qt.binding(function () { return root.luci })
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                id: clock
                color: root.luci.fg
                font.family: root.luci.fontFamily
                font.pointSize: 11
                text: Qt.formatDateTime(clockSource.date, "ddd dd MMM hh:mm")

                SystemClock {
                    id: clockSource
                    precision: SystemClock.Minutes
                }
            }
        }
    }
}
