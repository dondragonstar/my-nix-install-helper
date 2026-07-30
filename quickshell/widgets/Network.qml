import QtQuick

Pill {
    id: root

    content: Text {
        text: netsvc.state === "wifi" ? ("󰖩 " + netsvc.signal + "%")
            : netsvc.state === "ethernet" ? "󰈀"
            : "󰖪"
        color: netsvc.state === "disconnected" ? theme.dimText : theme.text
        font.family: theme.font
        font.pixelSize: theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            netsvc.scan();
            netPopup.visible = !netPopup.visible;
        }
    }
}
