import QtQuick

Pill {
    id: root

    function updateTime() {
        timeLabel.text = Qt.formatDateTime(new Date(), "HH:mm");
        dateLabel.text = Qt.formatDateTime(new Date(), "ddd dd MMM");
    }

    content: Row {
        spacing: 8

        Text {
            id: dateLabel
            font.family: theme.font
            font.pixelSize: theme.fontSize - 1
            color: theme.dimText
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: timeLabel
            font.family: theme.font
            font.pixelSize: theme.fontSize
            font.bold: true
            color: theme.text
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateTime()
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: calPopup.visible = !calPopup.visible
    }

    Component.onCompleted: updateTime()
}
