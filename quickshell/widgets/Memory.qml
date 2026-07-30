import QtQuick
import Quickshell.Io

Pill {
    id: root

    Process {
        id: btopProc
        command: ["alacritty", "--title", "btop", "-e", "btop"]
    }

    content: Text {
        text: "󰘚 " + sysinfo.memPct + "%"
        color: sysinfo.memPct >= 90 ? theme.critical
             : sysinfo.memPct >= 70 ? theme.warning
             : theme.text
        font.family: theme.font
        font.pixelSize: theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: btopProc.running = true
    }
}
