import Quickshell
import QtQuick
import "services"
import "popups"

ShellRoot {
    Theme { id: theme }
    Sysinfo { id: sysinfo }
    BacklightSvc { id: backlight }
    NetworkSvc { id: netsvc }
    BluetoothSvc { id: btsvc }

    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar {
                property var modelData
                screen: modelData
            }
        }
    }
}
