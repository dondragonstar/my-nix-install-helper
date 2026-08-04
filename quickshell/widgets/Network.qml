import QtQuick
import Quickshell.Io

Pill {
    id: root

    Process {
        id: wlctlProc
        command: ["wlctl-launcher"]
    }

    content: Text {
        text: netsvc.state === "wifi" ? ("󰖩 " + netsvc.signal + "%")
            : netsvc.state === "ethernet" ? "󰈀"
            : "󰖪"
        color: netsvc.state === "disconnected" ? theme.dimText : theme.text
        font.family: theme.font
        font.pixelSize: theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                wlctlProc.running = true;
            } else {
                networkPopup.visible = !networkPopup.visible;
            }
        }

        Rectangle {
            id: netTooltip
            visible: parent.containsMouse && netsvc.ssid !== ""
            width: netTipText.implicitWidth + 16
            height: netTipText.implicitHeight + 10
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: 8
            x: -width / 2 + parent.width / 2
            y: parent.height + 6
            z: 100

            Text {
                id: netTipText
                anchors.centerIn: parent
                text: netsvc.ssid + (netsvc.ipaddr ? "\n" + netsvc.ipaddr : "")
                color: theme.text
                font.family: theme.font
                font.pixelSize: theme.fontSize - 2
            }
        }
    }
}
