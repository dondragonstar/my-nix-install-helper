import QtQuick
import Quickshell.Io

Pill {
    id: root

    Process {
        id: btopProc
        command: ["alacritty", "--title", "btop", "-e", "btop"]
    }

    content: Text {
        text: "󰍛 " + sysinfo.cpuPct + "%"
        color: sysinfo.cpuPct >= 90 ? theme.critical
             : sysinfo.cpuPct >= 70 ? theme.warning
             : theme.text
        font.family: theme.font
        font.pixelSize: theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                cpuTooltip.visible = !cpuTooltip.visible;
            } else {
                btopProc.running = true;
            }
        }
    }
}
