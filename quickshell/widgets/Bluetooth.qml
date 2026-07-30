import QtQuick
import Quickshell.Io

Pill {
    id: root

    Process {
        id: bluetuithProc
        command: ["bluetuith-launcher"]
    }

    content: Text {
        text: !btsvc.powered ? "󰂲" : btsvc.connected ? "󰂱" : "󰂯"
        color: btsvc.connected ? theme.accent : btsvc.powered ? theme.text : theme.dimText
        font.family: theme.font
        font.pixelSize: theme.fontSize

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: bluetuithProc.running = true

        Rectangle {
            id: btTooltip
            visible: parent.containsMouse && btsvc.connectedName !== ""
            width: btTipText.implicitWidth + 16
            height: btTipText.implicitHeight + 10
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: 8
            x: -width / 2 + parent.width / 2
            y: parent.height + 6
            z: 100

            Text {
                id: btTipText
                anchors.centerIn: parent
                text: btsvc.connectedName
                color: theme.text
                font.family: theme.font
                font.pixelSize: theme.fontSize - 2
            }
        }
    }
}
