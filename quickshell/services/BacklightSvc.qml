import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property int pct: 0

    property Process backlightProc: Process {
        command: ["sh", "-c", "echo \"$(cat /sys/class/backlight/intel_backlight/brightness) $(cat /sys/class/backlight/intel_backlight/max_brightness)\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(/\s+/).map(Number);
                var brightness = parts[0];
                var maxBrightness = parts[1];

                if (!isNaN(brightness) && !isNaN(maxBrightness) && maxBrightness > 0) {
                    root.pct = Math.round(100 * brightness / maxBrightness);
                }
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: backlightProc.running = true
        Component.onCompleted: triggered()
    }
}
