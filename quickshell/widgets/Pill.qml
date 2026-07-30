import QtQuick

Rectangle {
    id: pill

    default property alias content: contentItem.data
    property bool hovered: hoverArea.containsMouse

    implicitWidth: contentItem.childrenRect.width + theme.itemPadH * 2
    implicitHeight: theme.barHeight - theme.itemMargin * 2

    color: hovered ? Qt.lighter(theme.itemBg, 1.25) : theme.itemBg
    radius: theme.radius
    border.color: hovered ? "#15ffffff" : "transparent"
    border.width: 1

    Behavior on color {
        ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on border.color {
        ColorAnimation { duration: 180 }
    }

    scale: hovered ? 1.03 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    Item {
        id: contentItem
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
