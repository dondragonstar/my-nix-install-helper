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

        Clock { id: clockWidget }
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
        Bluetooth {}
        Cpu { id: cpuWidget }
        Temperature {}
        Memory {}
        Backlight { id: backlightWidget }
        Volume { id: volumeWidget }
        Battery {}
        Tray { barWindow: bar._backingWindow ? bar._backingWindow : bar }
        SysMenu { id: sysMenuWidget }
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

    AudioPopup {
        id: audioPopup
        anchorItem: volumeWidget
    }

    CalendarPopup {
        id: calPopup
        anchorItem: clockWidget
    }

    NetworkPopup {
        id: networkPopup
        anchorItem: networkWidget
    }

    Osd {
        id: volumeOsd
        mode: "volume"
        anchorItem: volumeWidget
    }

    Osd {
        id: backlightOsd
        mode: "backlight"
        anchorItem: backlightWidget
    }
}
