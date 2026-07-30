import QtQuick
import Quickshell.Services.Pipewire

Pill {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    content: Text {
        readonly property string icon: root.muted ? "󰝟"
            : root.vol >= 0.7 ? "󰕾"
            : root.vol >= 0.3 ? "󰖀"
            : "󰕿"

        text: root.muted ? "󰝟" : (icon + " " + Math.round(root.vol * 100) + "%")
        color: root.muted ? theme.dimText : theme.text
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
                if (root.sink && root.sink.audio)
                    root.sink.audio.muted = !root.sink.audio.muted;
            } else {
                audioPopup.visible = !audioPopup.visible;
            }
        }
        onWheel: function(wheel) {
            if (root.sink && root.sink.audio) {
                var delta = wheel.angleDelta.y > 0 ? 0.02 : -0.02;
                root.sink.audio.volume = Math.max(0, Math.min(1.5, root.sink.audio.volume + delta));
            }
        }
    }
}
