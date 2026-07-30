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
}
