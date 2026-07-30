import Quickshell
import QtQuick

PopupWindow {
    id: popup

    property Item anchorItem

    anchor.item: anchorItem
    anchor.rect.y: theme.barHeight + 6
    grabFocus: true

    implicitWidth: 320
    color: "transparent"
    visible: false

    default property alias body: panel.data

    Rectangle {
        id: panel
        anchors.fill: parent
        color: theme.popupBg
        radius: theme.popupRadius
        border.color: theme.border
        border.width: 1

        opacity: popup.visible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        scale: popup.visible ? 1.0 : 0.95
        transformOrigin: Item.Top
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }

    Keys.onEscapePressed: popup.visible = false
}
