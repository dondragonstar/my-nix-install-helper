import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// On-screen display: small pill shown under its anchor widget (volume or
// brightness in the bar) when the value changes, auto-hides after a delay.
PopupWindow {
    id: osd

    property Item anchorItem
    property string mode: "volume"

    anchor.item: anchorItem
    anchor.rect.y: theme.barHeight + 6

    implicitWidth: 76
    implicitHeight: pillCol.implicitHeight + 28

    color: "transparent"
    visible: osdVisible

    property bool osdVisible: false
    property string osdIcon: ""
    property string osdText: ""
    property real osdPct: 0

    function show(icon, text, pct) {
        osdIcon = icon;
        osdText = text;
        osdPct = Math.max(0, Math.min(100, pct));
        osdVisible = true;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.osdVisible = false
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        color: theme.popupBg
        radius: theme.popupRadius
        border.color: theme.border
        border.width: 1

        opacity: osd.osdVisible ? 1.0 : 0.0
        scale: osd.osdVisible ? 1.0 : 0.9
        transformOrigin: Item.Center

        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Column {
            id: pillCol
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: osd.osdIcon
                color: theme.accent
                font.family: theme.font
                font.pixelSize: 26
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: osd.osdText
                color: theme.text
                font.family: theme.font
                font.pixelSize: theme.fontSize
                font.bold: true
            }

            Rectangle {
                id: track
                width: 6
                height: 110
                radius: 3
                color: theme.itemBg
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    id: fill
                    width: parent.width
                    height: track.height * osd.osdPct / 100
                    radius: 3
                    color: theme.accent
                    anchors.bottom: parent.bottom

                    Behavior on height {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    // ── volume tracking ──
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    property bool volInit: false

    onVolChanged: {
        if (osd.mode !== "volume") return;
        if (!volInit) { volInit = true; return; }
        var pct = Math.round(vol * 100);
        if (muted) {
            show("󰝟", pct + "%", pct);
        } else {
            show(pct >= 70 ? "󰕾" : pct >= 30 ? "󰖀" : "󰕿", pct + "%", pct);
        }
    }

    onMutedChanged: {
        if (osd.mode !== "volume") return;
        if (!volInit) { volInit = true; return; }
        show("󰝟", Math.round(vol * 100) + "%", Math.round(vol * 100));
    }

    // ── brightness tracking ──
    property bool backlightInit: false

    Connections {
        target: backlight
        function onPctChanged() {
            if (osd.mode !== "backlight") return;
            if (!osd.backlightInit) { osd.backlightInit = true; return; }
            osd.show("󰃠", backlight.pct + "%", backlight.pct);
        }
    }
}
