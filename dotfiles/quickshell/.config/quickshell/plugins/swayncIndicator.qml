// plugins/swayncIndicator.qml — unread-dot for swaync (kept for v0.1).
// Polls `swaync-client -swb` (same source the old waybar module used).
// Click toggles the control center. Drop-in example for ported widgets:
// any plugins/<name>.qml with an optional `luci` property works.
import QtQuick
import Quickshell
import Quickshell.Io

Text {
    property var luci: ({ fg: "#cdd6f4", accent: "#89b4fa", fontFamily: "monospace" })

    property bool hasUnread: false
    text: hasUnread ? " ●" : ""
    color: hasUnread ? luci.accent : luci.fg
    font.family: luci.fontFamily
    font.pointSize: 11

    Process {
        running: true
        command: ["sh", "-c", "swaync-client -swb 2>/dev/null || echo false"]
        stdout: StdioCollector {
            onStreamFinished: parent.parent.hasUnread = (text.trim() === "true")
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Quickshell.execDetached(["swaync-client", "-t", "-sw"])
    }
}
