import QtQuick

Pill {
    id: root

    content: Text {
        text: "󰐥"
        color: root.hovered ? theme.critical : theme.text
        font.family: theme.font
        font.pixelSize: theme.fontSize + 1

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: powerMenu.visible = !powerMenu.visible
    }
}
