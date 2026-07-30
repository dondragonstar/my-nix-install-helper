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
             : root.charging ? "#8be9fd"
             : theme.text
        font.family: theme.font
        font.pixelSize: theme.fontSize
    }
}
