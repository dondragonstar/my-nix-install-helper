import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

Row {
    id: root
    spacing: 10

    property var barWindow

    Repeater {
        model: SystemTray.items

        delegate: MouseArea {
            id: trayItem
            required property var modelData

            width: 20
            height: 20

            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true

            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    if (trayItem.modelData.hasMenu) {
                        trayItem.modelData.display(root.barWindow, trayItem.x, theme.barHeight);
                    }
                } else {
                    if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu) {
                        trayItem.modelData.display(root.barWindow, trayItem.x, theme.barHeight);
                    } else {
                        trayItem.modelData.activate();
                    }
                }
            }

            IconImage {
                anchors.fill: parent
                source: trayItem.modelData.icon

                opacity: trayItem.containsMouse ? 1.0 : 0.7
                Behavior on opacity {
                    NumberAnimation { duration: 120 }
                }
            }
        }
    }
}
