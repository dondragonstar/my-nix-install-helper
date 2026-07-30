import Quickshell.Io
import QtQuick

// Polls system stats every 2 seconds: CPU usage %, memory usage %, and
// coretemp package temperature (°C). Exposes cpuPct / memPct / tempC as
// plain int properties consumable by any widget in scope.
QtObject {
    id: root

    property int cpuPct: 0
    property int memPct: 0
    property int tempC: 0

    property real _prevIdle: 0
    property real _prevTotal: 0

    property Process cpuProc: Process {
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                // Format: "cpu  user nice system idle iowait irq softirq steal ..."
                var parts = data.trim().split(/\s+/).slice(1).map(Number);
                var idle = parts[3] + parts[4];
                var total = parts.reduce((a, b) => a + b, 0);

                var deltaIdle = idle - root._prevIdle;
                var deltaTotal = total - root._prevTotal;

                if (root._prevTotal !== 0 && deltaTotal > 0) {
                    root.cpuPct = Math.round(100 * (deltaTotal - deltaIdle) / deltaTotal);
                }

                root._prevIdle = idle;
                root._prevTotal = total;
            }
        }
    }

    property Process memProc: Process {
        command: ["awk", "/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf \"%d\", (t-a)*100/t}", "/proc/meminfo"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.trim(), 10);
                if (!isNaN(v)) root.memPct = v;
            }
        }
    }

    property Process tempProc: Process {
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); if [ \"$n\" = coretemp ]; then for l in $h/temp*_label; do grep -q \"Package id 0\" \"$l\" && { cat \"${l%_label}_input\"; exit; }; done; fi; done; cat /sys/class/hwmon/hwmon3/temp1_input 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.trim(), 10);
                if (!isNaN(v)) root.tempC = Math.round(v / 1000);
            }
        }
    }

    property Timer pollTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true;
            memProc.running = true;
            tempProc.running = true;
        }
        Component.onCompleted: triggered()
    }
}
