import Quickshell
import QtQuick

PopupBase {
    id: popup

    implicitHeight: Math.min(col.implicitHeight + 24, 420)

    Column {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 8

        Row {
            width: parent.width
            height: 28

            Text {
                text: "Bluetooth"
                color: theme.text
                font.family: theme.font
                font.bold: true
                font.pixelSize: theme.fontSize + 1
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - toggleBg.width
            }

            Rectangle {
                id: toggleBg
                width: 42
                height: 22
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: btsvc.powered ? theme.accent : theme.itemBg
                border.color: theme.border
                border.width: 1

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }

                Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    y: 3
                    x: btsvc.powered ? parent.width - width - 3 : 3
                    color: "white"

                    Behavior on x {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: btsvc.powerToggle()
                }
            }
        }

        Text {
            width: parent.width
            visible: btsvc.connected
            text: "Connected: " + btsvc.connectedName
            color: theme.dimText
            font.family: theme.font
            font.pixelSize: theme.fontSize - 1
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: !btsvc.connected && btsvc.powered
            text: "Not connected"
            color: theme.dimText
            font.family: theme.font
            font.pixelSize: theme.fontSize - 1
        }

        Rectangle {
            width: parent.width
            height: 1
            color: theme.border
        }

        ListView {
            id: listView
            width: parent.width
            height: Math.min(contentHeight, 280)
            clip: true
            spacing: 4
            model: btsvc.devices
            visible: btsvc.powered

            delegate: Rectangle {
                width: listView.width
                height: 36
                radius: theme.radius - 2
                color: modelData.connected ? theme.activeItemBg
                     : devMouse.containsMouse ? Qt.lighter(theme.itemBg, 1.2)
                     : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                property string rowMac: modelData.mac
                property string rowName: modelData.name
                property bool rowConnected: modelData.connected

                Row {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 8

                    Text {
                        text: "󰂯"
                        color: rowConnected ? theme.accent : theme.dimText
                        font.family: theme.font
                        font.pixelSize: theme.fontSize
                    }

                    Text {
                        text: rowName
                        color: rowConnected ? theme.activeText : theme.text
                        font.family: theme.font
                        font.pixelSize: theme.fontSize
                        elide: Text.ElideRight
                        width: parent.width - 90
                    }

                    Text {
                        visible: rowConnected
                        text: "✓"
                        color: theme.accent
                        font.family: theme.font
                        font.pixelSize: theme.fontSize
                    }
                }

                MouseArea {
                    id: devMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (rowConnected) {
                            btsvc.disconnectDevice(rowMac);
                        } else {
                            btsvc.connectDevice(rowMac);
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: !btsvc.powered
            text: "Bluetooth is off"
            color: theme.dimText
            font.family: theme.font
            font.pixelSize: theme.fontSize
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            width: parent.width
            height: 32
            radius: theme.radius - 2
            color: scanMouse.containsMouse ? Qt.lighter(theme.itemBg, 1.2) : theme.itemBg
            border.color: theme.border
            border.width: 1
            visible: btsvc.powered

            Behavior on color {
                ColorAnimation { duration: 100 }
            }

            Text {
                anchors.centerIn: parent
                text: "󰑐  Scan"
                color: theme.text
                font.family: theme.font
                font.pixelSize: theme.fontSize
            }

            MouseArea {
                id: scanMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: btsvc.scan()
            }
        }
    }
}
