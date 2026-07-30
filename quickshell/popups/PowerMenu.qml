import Quickshell
import QtQuick
import Quickshell.Io

PopupBase {
    id: popup

    implicitWidth: 240
    implicitHeight: col.implicitHeight + 24

    Column {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 6

        Text {
            text: "Power"
            color: theme.text
            font.family: theme.font
            font.pixelSize: theme.fontSize + 2
            font.bold: true
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#22ffffff"
        }

        Repeater {
            model: [
                { label: "Lock",      icon: "󰌾", cmd: ["hyprlock"] },
                { label: "Logout",    icon: "󰍃", cmd: ["hyprctl", "dispatch", "exit"] },
                { label: "Suspend",   icon: "󰤄", cmd: ["systemctl", "suspend"] },
                { label: "Reboot",    icon: "󰜉", cmd: ["systemctl", "reboot"] },
                { label: "Power Off", icon: "󰐥", cmd: ["systemctl", "poweroff"] }
            ]

            delegate: Rectangle {
                width: col.width
                height: 36
                radius: theme.radius
                color: rowArea.containsMouse ? theme.activeItemBg : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Row {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                    }
                    spacing: 10

                    Text {
                        text: modelData.icon
                        color: rowArea.containsMouse ? theme.activeText : theme.text
                        font.family: theme.font
                        font.pixelSize: theme.fontSize + 1
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: modelData.label
                        color: rowArea.containsMouse ? theme.activeText : theme.text
                        font.family: theme.font
                        font.pixelSize: theme.fontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Process {
                    id: actionProc
                    command: modelData.cmd
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        actionProc.running = true;
                        popup.visible = false;
                    }
                }
            }
        }
    }
}
