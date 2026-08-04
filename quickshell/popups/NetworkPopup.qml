import Quickshell
import QtQuick
import QtQuick.Controls

PopupBase {
    id: popup

    property string selectedSsid: ""
    property string passwordText: ""

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
                text: "Wi-Fi"
                color: theme.text
                font.family: theme.font
                font.pixelSize: theme.fontSize + 1
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - toggleBg.width
            }

            Rectangle {
                id: toggleBg
                width: 42
                height: 22
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: netsvc.wifiEnabled ? theme.accent : theme.itemBg
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
                    x: netsvc.wifiEnabled ? parent.width - width - 3 : 3
                    color: "white"

                    Behavior on x {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: netsvc.toggleWifi()
                }
            }
        }

        Text {
            width: parent.width
            visible: netsvc.state === "wifi" && netsvc.ssid !== ""
            text: "Connected: " + netsvc.ssid + (netsvc.ipaddr ? " (" + netsvc.ipaddr + ")" : "") + " · " + netsvc.signal + "%"
            color: theme.dimText
            font.family: theme.font
            font.pixelSize: theme.fontSize - 1
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: netsvc.state !== "wifi"
            text: netsvc.state === "ethernet" ? "Connected via Ethernet" : "Not connected"
            color: theme.dimText
            font.family: theme.font
            font.pixelSize: theme.fontSize - 1
        }

        Row {
            width: parent.width
            visible: netsvc.state !== "disconnected" && (netsvc.downKbps > 0 || netsvc.upKbps > 0)
            spacing: 12

            Text {
                text: "󰇚 " + netsvc.fmtRate(netsvc.downKbps)
                color: theme.success
                font.family: theme.font
                font.pixelSize: theme.fontSize - 1
            }

            Text {
                text: "󰕒 " + netsvc.fmtRate(netsvc.upKbps)
                color: theme.warning
                font.family: theme.font
                font.pixelSize: theme.fontSize - 1
            }
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
            model: netsvc.wifiList
            visible: netsvc.wifiEnabled

            delegate: Column {
                width: listView.width
                spacing: 4

                property string rowSsid: modelData.ssid
                property int rowSignal: modelData.signal
                property bool rowInUse: modelData.inUse

                Rectangle {
                    width: parent.width
                    height: 36
                    radius: theme.radius - 2
                    color: rowInUse ? theme.activeItemBg : rowMouse.containsMouse ? Qt.lighter(theme.itemBg, 1.2) : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

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
                            text: rowSignal >= 75 ? "󰤨"
                                : rowSignal >= 50 ? "󰤥"
                                : rowSignal >= 25 ? "󰤢"
                                : "󰤟"
                            color: rowInUse ? theme.accent : theme.text
                            font.family: theme.font
                            font.pixelSize: theme.fontSize
                        }

                        Text {
                            text: rowSsid
                            color: rowInUse ? theme.activeText : theme.text
                            font.family: theme.font
                            font.pixelSize: theme.fontSize
                            elide: Text.ElideRight
                            width: parent.width - 90
                        }

                        Text {
                            visible: rowInUse
                            text: "✓"
                            color: theme.accent
                            font.family: theme.font
                            font.pixelSize: theme.fontSize
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (rowInUse) return;
                            popup.selectedSsid = (popup.selectedSsid === rowSsid) ? "" : rowSsid;
                            popup.passwordText = "";
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: visible ? 32 : 0
                    visible: popup.selectedSsid === rowSsid
                    spacing: 6

                    Behavior on height {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }

                    property bool showPass: false

                    TextField {
                        id: passField
                        width: parent.width - eyeBtn.width - connectBtn.width - 12
                        height: 32
                        placeholderText: "Password"
                        echoMode: showPass ? TextInput.Normal : TextInput.Password
                        font.family: theme.font
                        font.pixelSize: theme.fontSize - 1
                        color: theme.text
                        background: Rectangle {
                            radius: theme.radius - 2
                            color: theme.itemBg
                            border.color: passField.activeFocus ? theme.accent : theme.border
                            border.width: 1
                        }
                        onTextChanged: popup.passwordText = text
                        onAccepted: connectBtn.doConnect()
                        Component.onCompleted: if (popup.selectedSsid === rowSsid) forceActiveFocus()
                    }

                    Rectangle {
                        id: eyeBtn
                        width: 32
                        height: 32
                        radius: theme.radius - 2
                        color: eyeMouse.containsMouse ? theme.activeItemBg : theme.itemBg

                        Text {
                            anchors.centerIn: parent
                            text: showPass ? "󰈈" : "󰈉"
                            color: theme.text
                            font.family: theme.font
                            font.pixelSize: theme.fontSize
                        }

                        MouseArea {
                            id: eyeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: showPass = !showPass
                        }
                    }

                    Rectangle {
                        id: connectBtn
                        width: 70
                        height: 32
                        radius: theme.radius - 2
                        color: connMouse.containsMouse ? Qt.lighter(theme.accent, 1.1) : theme.accent

                        Behavior on color {
                            ColorAnimation { duration: 100 }
                        }

                        function doConnect() {
                            netsvc.connect(rowSsid, passField.text);
                            popup.selectedSsid = "";
                            popup.passwordText = "";
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Connect"
                            color: "#111111"
                            font.family: theme.font
                            font.pixelSize: theme.fontSize - 1
                            font.bold: true
                        }

                        MouseArea {
                            id: connMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: connectBtn.doConnect()
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: !netsvc.wifiEnabled
            text: "Wi-Fi is off"
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
                onClicked: netsvc.scan()
            }
        }
    }
}
