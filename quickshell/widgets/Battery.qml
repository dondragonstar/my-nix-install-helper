import QtQuick
import Quickshell.Io

Pill {
    id: root

    property int cap: -1
    property string status: ""

    readonly property bool charging: status === "Charging"

    visible: cap >= 0

    Process {
        id: batProc
        command: ["sh", "-c", "echo \"$(cat /sys/class/power_supply/BAT1/capacity):$(cat /sys/class/power_supply/BAT1/status)\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                var c = parseInt(parts[0], 10);
                if (!isNaN(c)) root.cap = c;
                root.status = parts[1] || "";
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: batProc.running = true
        Component.onCompleted: triggered()
    }

    content: Text {
        readonly property string icon: {
            if (root.charging) return "󰂄";
            if (root.cap <= 10) return "󰁺";
            if (root.cap <= 20) return "󰁻";
            if (root.cap <= 30) return "󰁼";
            if (root.cap <= 40) return "󰁽";
            if (root.cap <= 50) return "󰁾";
            if (root.cap <= 60) return "󰁿";
            if (root.cap <= 70) return "󰂀";
            if (root.cap <= 80) return "󰂁";
            if (root.cap <= 90) return "󰂂";
            return "󰁹";
        }

        text: icon + " " + root.cap + "%"
        color: root.cap <= 15 ? theme.critical
             : root.cap <= 30 ? theme.warning
             : root.charging ? theme.accent
             : theme.text
        font.family: theme.font
        font.pixelSize: theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        Rectangle {
            id: batTooltip
            visible: parent.containsMouse
            width: batTipText.implicitWidth + 16
            height: batTipText.implicitHeight + 10
            color: theme.popupBg
            border.color: theme.border
            border.width: 1
            radius: 8
            x: -width / 2 + parent.width / 2
            y: parent.height + 6
            z: 100

            Text {
                id: batTipText
                anchors.centerIn: parent
                text: root.status + " · " + root.cap + "%"
                color: theme.text
                font.family: theme.font
                font.pixelSize: theme.fontSize - 2
            }
        }
    }
}
