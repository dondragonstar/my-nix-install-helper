import Quickshell
import QtQuick
import "widgets"
import "popups"

PanelWindow {
    id: bar

    anchors {
        top: true
        left: true
        right: true
    }

    height: theme.barHeight
    color: theme.barBg

    Row {
        id: leftRow
        spacing: theme.spacing
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: theme.spacing + 2
        }

        Workspaces {}
        WindowTitle {}
        Media { id: mediaWidget }
    }

    Row {
        id: centerRow
        spacing: theme.spacing
        anchors.centerIn: parent

        Clock {}
    }

    Row {
        id: rightRow
        spacing: theme.spacing
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: theme.spacing + 2
        }

        Network { id: networkWidget }
        Bluetooth { id: bluetoothWidget }
        Cpu { id: cpuWidget }
        Temperature {}
        Memory {}
        Backlight {}
        Volume {}
        Battery {}
        Tray { barWindow: bar }
        SysMenu { id: sysMenuWidget }
    }

    NetworkPopup {
        id: netPopup
        anchorItem: networkWidget
    }

    BluetoothPopup {
        id: btPopup
        anchorItem: bluetoothWidget
    }

    MediaPopup {
        id: mediaPopup
        anchorItem: mediaWidget
    }

    PowerMenu {
        id: powerMenu
        anchorItem: sysMenuWidget
    }

    CpuTooltip {
        id: cpuTooltip
        anchorItem: cpuWidget
    }
}
