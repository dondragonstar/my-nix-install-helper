import Quickshell.Io
import QtQuick

// Polls bluetooth state every 5 seconds via bluetoothctl. Exposes powered
// state, whether a device is connected, and the connected device's name
// as plain properties consumable by any widget in scope.
//
// Task 2.3 additions: interactive device list (scan/connect/disconnect/power
// toggle) backing the BluetoothPopup. `devices` is populated by
// `listDevices()`, which shells out to `bluetoothctl devices` (format
// "Device XX:XX:XX:XX:XX:XX Name") and cross-references `bluetoothctl devices
// Connected` to set the `connected` flag per device. `scan()` runs a timed
// `bluetoothctl --timeout 8 scan on` and calls `listDevices()` once it exits.
// `connectDevice()`/`disconnectDevice()`/`powerToggle()` are fire-and-forget
// Process calls (no output parsing needed beyond letting the next
// poll/listDevices pick up the new state).
QtObject {
    id: root

    property bool powered: false
    property bool connected: false
    property string connectedName: ""

    // Array of { mac: string, name: string, connected: bool }, populated by
    // listDevices().
    property var devices: []

    function powerToggle() {
        root.powered = !root.powered;
        powerProc.command = ["bluetoothctl", "power", root.powered ? "on" : "off"];
        powerProc.running = false;
        powerProc.running = true;
    }

    function scan() {
        scanProc.running = false;
        scanProc.running = true;
    }

    function connectDevice(mac) {
        connectProc.command = ["bluetoothctl", "connect", mac];
        connectProc.running = false;
        connectProc.running = true;
    }

    function disconnectDevice(mac) {
        disconnectProc.command = ["bluetoothctl", "disconnect", mac];
        disconnectProc.running = false;
        disconnectProc.running = true;
    }

    function listDevices() {
        listProc.running = false;
        listProc.running = true;
    }

    property Process btProc: Process {
        command: ["sh", "-c", "pw=$(bluetoothctl show | awk '/Powered:/{print $2; exit}'); dev=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-); echo \"$pw|$dev\""]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                var newPowered = parts[0] === "yes";
                var newName = parts[1] || "";

                root.powered = newPowered;
                root.connectedName = newName;
                root.connected = newName.length > 0;
            }
        }
    }

    // Runs `bluetoothctl devices` then `bluetoothctl devices Connected`,
    // separated by a marker line, so a single Process invocation can build
    // the full devices array (mac, name, connected) in one shot.
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

                // Expected format: "Device XX:XX:XX:XX:XX:XX DeviceName"
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
        onExited: {
            root.listDevices();
        }
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
        onExited: {
            btProc.running = true;
        }
    }

    property Timer pollTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            btProc.running = true;
        }
        Component.onCompleted: triggered()
    }
}
