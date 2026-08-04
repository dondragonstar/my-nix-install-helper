import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property string state: "disconnected"
    property int signal: 0
    property string ssid: ""
    property string ipaddr: ""
    property var wifiList: []
    property bool wifiEnabled: true

    property real downKbps: 0
    property real upKbps: 0

    property real lastRx: 0
    property real lastTx: 0
    property real lastStamp: 0
    property string lastIface: ""

    function fmtRate(kbps) {
        if (kbps >= 1024) return (kbps / 1024).toFixed(1) + " MB/s";
        return Math.round(kbps) + " KB/s";
    }

    function scan() {
        wifiList = [];
        scanProc.running = true;
    }

    function connect(targetSsid, pass) {
        var escaped = targetSsid.replace(/'/g, "'\\''");
        var cmd;
        if (pass) {
            var escapedPass = pass.replace(/'/g, "'\\''");
            cmd = ["sh", "-c", "nmcli dev wifi connect '" + escaped + "' password '" + escapedPass + "'"];
        } else {
            cmd = ["sh", "-c", "nmcli dev wifi connect '" + escaped + "'"];
        }
        connectProc.command = cmd;
        Qt.callLater(function() { connectProc.running = true; });
    }

    function toggleWifi() {
        root.wifiEnabled = !root.wifiEnabled;
        wifiToggleProc.command = ["nmcli", "radio", "wifi", root.wifiEnabled ? "on" : "off"];
        Qt.callLater(function() { wifiToggleProc.running = true; });
    }

    property Process ipProc: Process {
        command: ["sh", "-c", "ip -4 -br addr show | awk '/UP/{gsub(/\\/.*/, \"\", $3); print $3; exit}'"]
        stdout: SplitParser {
            onRead: data => {
                root.ipaddr = data.trim();
            }
        }
    }

    property Process netProc: Process {
        command: ["sh", "-c", "t=$(nmcli -t -f TYPE,STATE -e no dev status | awk -F: '$2==\"connected\"{print $1; exit}'); if [ \"$t\" = wifi ]; then s=$(nmcli -t -f IN-USE,SIGNAL,SSID -e no dev wifi | awk -F: '$1==\"*\"{print $2\":\"$3; exit}'); echo \"wifi:$s\"; elif [ \"$t\" = ethernet ]; then echo 'ethernet::'; else echo 'disconnected::'; fi"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":");
                var newState = parts[0] || "disconnected";
                var newSignal = parseInt(parts[1], 10);
                var newSsid = parts[2] || "";

                root.state = newState;
                root.signal = isNaN(newSignal) ? 0 : newSignal;
                root.ssid = newSsid;
            }
        }
    }

    property Process scanProc: Process {
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SSID", "-e", "no", "dev", "wifi", "list"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line.length === 0) return;

                var parts = line.split(":");
                var inUse = parts[0] === "*";
                var sig = parseInt(parts[1], 10);
                var name = parts.slice(2).join(":");

                if (!name) return;

                var list = root.wifiList.slice();
                var existingIdx = -1;
                for (var i = 0; i < list.length; i++) {
                    if (list[i].ssid === name) {
                        existingIdx = i;
                        break;
                    }
                }

                var entry = {
                    ssid: name,
                    signal: isNaN(sig) ? 0 : sig,
                    inUse: inUse
                };

                if (existingIdx >= 0) {
                    if (entry.signal > list[existingIdx].signal) {
                        list[existingIdx] = entry;
                    }
                } else {
                    list.push(entry);
                }

                list.sort(function(a, b) { return b.signal - a.signal; });
                root.wifiList = list;
            }
        }
    }

    property Process connectProc: Process {
        command: ["true"]
        onExited: {
            netProc.running = true;
            ipProc.running = true;
            Qt.callLater(function() { root.scan(); });
        }
    }

    property Process wifiToggleProc: Process {
        command: ["true"]
    }

    property Process speedProc: Process {
        command: ["sh", "-c", "i=$(nmcli -t -f DEVICE,STATE -e no dev status | awk -F: '$2==\"connected\"{print $1; exit}'); if [ -n \"$i\" ] && [ -r \"/sys/class/net/$i/statistics/rx_bytes\" ]; then echo \"$i $(cat /sys/class/net/$i/statistics/rx_bytes) $(cat /sys/class/net/$i/statistics/tx_bytes)\"; else echo none; fi"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(/\s+/);
                var iface = parts[0];
                if (iface === "none") {
                    root.downKbps = 0;
                    root.upKbps = 0;
                    return;
                }

                var rx = parseInt(parts[1], 10);
                var tx = parseInt(parts[2], 10);
                if (isNaN(rx) || isNaN(tx)) return;

                var now = Date.now();
                if (root.lastIface === iface && root.lastStamp > 0) {
                    var dt = (now - root.lastStamp) / 1000;
                    if (dt > 0) {
                        root.downKbps = Math.max(0, (rx - root.lastRx) / dt / 1024);
                        root.upKbps = Math.max(0, (tx - root.lastTx) / dt / 1024);
                    }
                }

                root.lastIface = iface;
                root.lastRx = rx;
                root.lastTx = tx;
                root.lastStamp = now;
            }
        }
    }

    property Timer speedTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: speedProc.running = true
        Component.onCompleted: triggered()
    }

    property Timer pollTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            netProc.running = true;
            ipProc.running = true;
        }
        Component.onCompleted: triggered()
    }
}
