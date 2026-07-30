import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property bool powered: false
    property bool connected: false
    property string connectedName: ""
    property var devices: []

    function powerToggle() {
        root.powered = !root.powered;
        powerProc.command = ["bluetoothctl", "power", root.powered ? "on" : "off"];
        Qt.callLater(function() { powerProc.running = true; });
    }

    function scan() {
        scanProc.running = true;
    }

    function connectDevice(mac) {
        connectProc.command = ["sh", "-c", "bluetoothctl connect " + mac + " && sleep 2 && bluetoothctl devices Connected"];
        Qt.callLater(function() { connectProc.running = true; });
    }

    function disconnectDevice(mac) {
        disconnectProc.command = ["bluetoothctl", "disconnect", mac];
        Qt.callLater(function() { disconnectProc.running = true; });
    }

    function listDevices() {
        listProc.running = true;
    }

    property Process btProc: Process {
        command: ["sh", "-c", "pw=$(bluetoothctl show | awk '/Powered:/{print $2; exit}'); dev=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-); echo \"$pw|$dev\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                root.powered = parts[0] === "yes";
                root.connectedName = parts[1] || "";
                root.connected = root.connectedName.length > 0;
            }
        }
    }

    property Process listProc: Process {
        command: ["sh", "-c", "bluetoothctl devices; echo '---CONNECTED---'; bluetoothctl devices Connected"]
        property var allDevices: []
        property var connectedMacs: []
        property bool inConnectedSection: false

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line.length === 0) return;

                if (line === "---CONNECTED---") {
                    listProc.inConnectedSection = true;
                    return;
                }

                var m = line.match(/^Device\s+(\S+)\s+(.*)$/);
                if (!m) return;

                var mac = m[1];
                var name = m[2];

                if (listProc.inConnectedSection) {
                    var conn = listProc.connectedMacs.slice();
                    conn.push(mac);
                    listProc.connectedMacs = conn;
                } else {
                    var list = listProc.allDevices.slice();
                    list.push({mac: mac, name: name});
                    listProc.allDevices = list;
                }
            }
        }

        onRunningChanged: {
            if (running) {
                allDevices = [];
                connectedMacs = [];
                inConnectedSection = false;
            }
        }

        onExited: {
            var result = [];
            for (var i = 0; i < allDevices.length; i++) {
                var d = allDevices[i];
                result.push({
                    mac: d.mac,
                    name: d.name,
                    connected: connectedMacs.indexOf(d.mac) !== -1
                });
            }
            root.devices = result;
        }
    }

    property Process scanProc: Process {
        command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
        onExited: root.listDevices()
    }

    property Process connectProc: Process {
        command: ["true"]
        onExited: {
            btProc.running = true;
            root.listDevices();
        }
    }

    property Process disconnectProc: Process {
        command: ["true"]
        onExited: {
            btProc.running = true;
            root.listDevices();
        }
    }

    property Process powerProc: Process {
        command: ["true"]
        onExited: btProc.running = true
    }

    property Timer pollTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: btProc.running = true
        Component.onCompleted: triggered()
    }
}
