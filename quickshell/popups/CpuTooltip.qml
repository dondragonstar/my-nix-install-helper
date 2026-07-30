import Quickshell
import Quickshell.Io
import QtQuick

PopupBase {
    id: popup

    implicitWidth: 220
    implicitHeight: col.implicitHeight + 24

    property var coreData: []
    property var _prevIdle: []
    property var _prevTotal: []

    Process {
        id: coreProc
        command: ["sh", "-c", "grep '^cpu[0-9]' /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                var lines = data.trim().split("\n");
                var results = [];
                var newIdle = [];
                var newTotal = [];
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/).slice(1).map(Number);
                    var idle = parts[3] + parts[4];
                    var total = parts.reduce(function(a, b) { return a + b; }, 0);
                    newIdle.push(idle);
                    newTotal.push(total);

                    var pct = 0;
                    if (popup._prevTotal.length > i && popup._prevTotal[i] > 0) {
                        var dIdle = idle - popup._prevIdle[i];
                        var dTotal = total - popup._prevTotal[i];
                        if (dTotal > 0) pct = Math.round(100 * (dTotal - dIdle) / dTotal);
                    }
                    results.push(pct);
                }
                popup._prevIdle = newIdle;
                popup._prevTotal = newTotal;
                popup.coreData = results;
            }
        }
    }

    Timer {
        interval: 1500
        running: popup.visible
        repeat: true
        onTriggered: coreProc.running = true
        Component.onCompleted: if (popup.visible) coreProc.running = true
    }

    onVisibleChanged: if (visible) coreProc.running = true

    Column {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 4

        Text {
            text: "CPU Cores"
            color: theme.text
            font.family: theme.font
            font.pixelSize: theme.fontSize
            font.bold: true
        }

        Rectangle {
            width: parent.width
            height: 1
            color: theme.border
        }

        Repeater {
            model: popup.coreData.length

            delegate: Row {
                required property int index
                width: col.width
                height: 18
                spacing: 8

                Text {
                    width: 32
                    text: index
                    color: theme.dimText
                    font.family: theme.font
                    font.pixelSize: theme.fontSize - 2
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: parent.width - 72
                    height: 8
                    radius: 4
                    color: theme.itemBg
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: parent.width * (popup.coreData[index] || 0) / 100
                        height: parent.height
                        radius: 4
                        color: (popup.coreData[index] || 0) >= 90 ? theme.critical
                             : (popup.coreData[index] || 0) >= 70 ? theme.warning
                             : theme.accent

                        Behavior on width {
                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Text {
                    width: 30
                    text: (popup.coreData[index] || 0) + "%"
                    color: theme.text
                    font.family: theme.font
                    font.pixelSize: theme.fontSize - 2
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
