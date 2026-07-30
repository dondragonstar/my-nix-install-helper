import QtQuick

Pill {
    id: root

    content: Text {
        text: !btsvc.powered ? "󰂲" : btsvc.connected ? "󰂱" : "󰂯"
        color: btsvc.connected ? theme.accent : btsvc.powered ? theme.text : theme.dimText
        font.family: theme.font
        font.pixelSize: theme.fontSize

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            btsvc.listDevices();
            btPopup.visible = !btPopup.visible;
        }
    }
}
