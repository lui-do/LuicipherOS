// shell.qml — LuicipherOS custom Quickshell shell v0.1.
// A minimal top bar + plugin host. Plugins drop into plugins/ as single
// .qml files exposing a `title` string; enable them in plugins.json.
// Written so widgets ported from Noctalia, DankMaterialShell, or Omarchy
// can slot in: each plugin gets bar height + palette via the `Luci` object.
// v0.1 scope: clock + swaync indicator + plugin row. Workspaces widget,
// system tray, and notification center arrive in v0.2 (swaync covers
// notifications until then — see dotfiles/swaync).
import Quickshell
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    // Shared tokens plugins can read: Luci.barHeight, Luci.accent, ...
    property var luci: ({
        barHeight: 30,
        accent: "#89b4fa",
        bg: "#1e1e2e",
        fg: "#cdd6f4",
        muted: "#6c7086",
        fontFamily: "JetBrainsMono Nerd Font"
    })

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

            // Plugin row: each plugins/<name>.qml gets `luci` injected.
            Repeater {
                model: root.pluginNames
                Loader {
                    source: Qt.resolvedUrl("plugins/" + modelData + ".qml")
                    onLoaded: { if (item.hasOwnProperty("luci")) item.luci = root.luci; }
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
