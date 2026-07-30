import Quickshell
import Quickshell.Services.Mpris
import QtQuick

PopupBase {
    id: popup

    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property bool playing: player ? player.isPlaying : false

    implicitWidth: 300
    implicitHeight: col.implicitHeight + 24

    Column {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 12

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 120
            height: 120
            radius: theme.popupRadius
            color: theme.itemBg
            clip: true

            Image {
                id: albumArt
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: popup.player ? popup.player.trackArtUrl : ""
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                text: "󰎈"
                color: theme.dimText
                font.family: theme.font
                font.pixelSize: 36
                visible: albumArt.status !== Image.Ready
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: popup.player ? popup.player.trackTitle : ""
            color: theme.text
            font.family: theme.font
            font.pixelSize: theme.fontSize + 2
            font.bold: true
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: popup.player ? popup.player.trackArtists : ""
            color: theme.dimText
            font.family: theme.font
            font.pixelSize: theme.fontSize
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Repeater {
                model: [
                    { icon: "󰒮", action: "previous" },
                    { icon: popup.playing ? "󰏤" : "󰐊", action: "toggle" },
                    { icon: "󰒭", action: "next" }
                ]

                delegate: Rectangle {
                    width: modelData.action === "toggle" ? 44 : 36
                    height: width
                    radius: width / 2
                    color: ctrlArea.containsMouse ? theme.activeItemBg : theme.itemBg

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }

                    scale: ctrlArea.pressed ? 0.9 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: 80 }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: ctrlArea.containsMouse ? theme.activeText : theme.text
                        font.family: theme.font
                        font.pixelSize: modelData.action === "toggle" ? theme.fontSize + 4 : theme.fontSize + 2
                    }

                    MouseArea {
                        id: ctrlArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!popup.player) return;
                            if (modelData.action === "previous") popup.player.previous();
                            else if (modelData.action === "toggle") popup.player.togglePlaying();
                            else popup.player.next();
                        }
                    }
                }
            }
        }
    }
}
