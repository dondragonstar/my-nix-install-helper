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
                        var pos = trayItem.mapToGlobal(mouse.x, mouse.y);
                        trayItem.modelData.display(root.barWindow, pos.x, pos.y);
                    } else {
                        trayItem.modelData.secondaryActivate();
                    }
                } else {
                    if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu) {
                        var pos2 = trayItem.mapToGlobal(0, trayItem.height);
                        trayItem.modelData.display(root.barWindow, pos2.x, pos2.y);
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

            Rectangle {
                id: trayTooltip
                visible: trayItem.containsMouse && trayItem.modelData.tooltipTitle !== ""
                width: trayTipText.implicitWidth + 12
                height: trayTipText.implicitHeight + 8
                color: theme.popupBg
                border.color: theme.border
                border.width: 1
                radius: 6
                x: -width / 2 + parent.width / 2
                y: parent.height + 6
                z: 100

                Text {
                    id: trayTipText
                    anchors.centerIn: parent
                    text: trayItem.modelData.tooltipTitle
                    color: theme.text
                    font.family: theme.font
                    font.pixelSize: theme.fontSize - 2
                }
            }
        }
    }
}
