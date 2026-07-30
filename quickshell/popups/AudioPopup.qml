import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

PopupBase {
    id: popup

    implicitWidth: 300
    implicitHeight: col.implicitHeight + 24

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Column {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 10

        Row {
            width: parent.width
            height: 28

            Text {
                text: "Audio"
                color: theme.text
                font.family: theme.font
                font.pixelSize: theme.fontSize + 1
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - muteBtn.width
            }

            Rectangle {
                id: muteBtn
                width: 36
                height: 28
                radius: theme.radius - 2
                anchors.verticalCenter: parent.verticalCenter
                color: muteMouse.containsMouse ? theme.activeItemBg : theme.itemBg

                Behavior on color {
                    ColorAnimation { duration: 100 }
                }

                Text {
                    anchors.centerIn: parent
                    text: popup.muted ? "󰝟" : "󰕾"
                    color: popup.muted ? theme.critical : theme.text
                    font.family: theme.font
                    font.pixelSize: theme.fontSize + 1
                }

                MouseArea {
                    id: muteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (popup.sink && popup.sink.audio)
                            popup.sink.audio.muted = !popup.sink.audio.muted;
                    }
                }
            }
        }

        Text {
            text: popup.sink ? (popup.sink.description || popup.sink.name || "Unknown") : "No output"
            color: theme.dimText
            font.family: theme.font
            font.pixelSize: theme.fontSize - 1
            elide: Text.ElideRight
            width: parent.width
        }

        Row {
            width: parent.width
            height: 32
            spacing: 10

            Text {
                text: Math.round(popup.vol * 100) + "%"
                color: popup.muted ? theme.dimText : theme.text
                font.family: theme.font
                font.pixelSize: theme.fontSize
                font.bold: true
                width: 40
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: parent.width - 50
                height: 32
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    id: sliderTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: theme.itemBg

                    Rectangle {
                        width: parent.width * Math.min(popup.vol, 1.5) / 1.5
                        height: parent.height
                        radius: 3
                        color: popup.muted ? theme.dimText
                             : popup.vol > 1.0 ? theme.warning
                             : theme.accent

                        Behavior on width {
                            NumberAnimation { duration: 50 }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }
                }

                Rectangle {
                    id: sliderKnob
                    width: 14
                    height: 14
                    radius: 7
                    color: "white"
                    y: parent.height / 2 - 7
                    x: sliderTrack.width * Math.min(popup.vol, 1.5) / 1.5 - 7

                    Behavior on x {
                        NumberAnimation { duration: 50 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(mouse) { setVolFromMouse(mouse.x); }
                    onPositionChanged: function(mouse) { if (pressed) setVolFromMouse(mouse.x); }

                    function setVolFromMouse(mx) {
                        var ratio = Math.max(0, Math.min(mx / width, 1.0));
                        var newVol = ratio * 1.5;
                        if (popup.sink && popup.sink.audio)
                            popup.sink.audio.volume = newVol;
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: theme.border
        }

        Text {
            text: "Output Devices"
            color: theme.dimText
            font.family: theme.font
            font.pixelSize: theme.fontSize - 1
        }

        ListView {
            id: sinkList
            width: parent.width
            height: Math.min(contentHeight, 200)
            clip: true
            spacing: 4

            model: Pipewire.nodes

            delegate: Item {
                id: sinkDelegate
                required property var modelData

                width: sinkList.width
                height: modelData.isSink && !modelData.isStream ? 36 : 0
                visible: modelData.isSink && !modelData.isStream
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: theme.radius - 2
                    visible: parent.visible
                    color: (Pipewire.defaultAudioSink && modelData.id === Pipewire.defaultAudioSink.id)
                         ? theme.activeItemBg
                         : sinkMouse.containsMouse ? Qt.lighter(theme.itemBg, 1.2)
                         : "transparent"

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
                            text: (Pipewire.defaultAudioSink && sinkDelegate.modelData.id === Pipewire.defaultAudioSink.id) ? "󰓃" : "󰓂"
                            color: (Pipewire.defaultAudioSink && sinkDelegate.modelData.id === Pipewire.defaultAudioSink.id) ? theme.accent : theme.dimText
                            font.family: theme.font
                            font.pixelSize: theme.fontSize
                        }

                        Text {
                            text: sinkDelegate.modelData.description || sinkDelegate.modelData.name || "Unknown"
                            color: (Pipewire.defaultAudioSink && sinkDelegate.modelData.id === Pipewire.defaultAudioSink.id) ? theme.activeText : theme.text
                            font.family: theme.font
                            font.pixelSize: theme.fontSize - 1
                            elide: Text.ElideRight
                            width: parent.width - 30
                        }
                    }

                    MouseArea {
                        id: sinkMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Pipewire.preferredDefaultAudioSink = sinkDelegate.modelData
                    }
                }
            }
        }
    }
}
