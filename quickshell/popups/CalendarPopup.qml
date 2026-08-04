import QtQuick

// Month calendar popup, anchored to the clock. Click a day to jump back to
// the current month; prev/next arrows navigate months.
PopupBase {
    id: popup

    implicitWidth: 280
    implicitHeight: col.implicitHeight + 24

    property date now: new Date()
    property int monthOffset: 0

    readonly property int dispYear: now.getFullYear() + Math.floor((now.getMonth() + monthOffset) / 12)
    readonly property int dispMonth: ((now.getMonth() + monthOffset) % 12 + 12) % 12
    readonly property int daysInMonth: new Date(dispYear, dispMonth + 1, 0).getDate()
    readonly property int firstWeekday: new Date(dispYear, dispMonth, 1).getDay()

    onVisibleChanged: {
        if (popup.visible) {
            popup.now = new Date();
            popup.monthOffset = 0;
        }
    }

    Column {
        id: col
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 8

        Row {
            width: parent.width
            height: 30

            Rectangle {
                width: 30
                height: 30
                radius: theme.radius - 2
                color: prevMouse.containsMouse ? theme.activeItemBg : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰁍"
                    color: theme.text
                    font.family: theme.font
                    font.pixelSize: theme.fontSize
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: popup.monthOffset--
                }
            }

            Text {
                width: parent.width - 60
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(new Date(popup.dispYear, popup.dispMonth, 1), "MMMM yyyy")
                color: theme.text
                font.family: theme.font
                font.pixelSize: theme.fontSize
                font.bold: true
            }

            Rectangle {
                width: 30
                height: 30
                radius: theme.radius - 2
                color: nextMouse.containsMouse ? theme.activeItemBg : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰁑"
                    color: theme.text
                    font.family: theme.font
                    font.pixelSize: theme.fontSize
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: popup.monthOffset++
                }
            }
        }

        Grid {
            id: grid
            columns: 7
            spacing: 4
            width: parent.width

            property real cellW: (grid.width - 6 * 4) / 7

            Repeater {
                model: 49

                delegate: Item {
                    required property int index

                    readonly property bool isHeader: index < 7
                    readonly property bool isCell: !isHeader
                    readonly property int day: isCell ? index - 7 - popup.firstWeekday + 1 : 0
                    readonly property bool inMonth: day >= 1 && day <= popup.daysInMonth
                    readonly property bool isToday: popup.monthOffset === 0 && day === popup.now.getDate()

                    width: grid.cellW
                    height: isHeader ? 22 : 30

                    Text {
                        anchors.centerIn: parent
                        visible: parent.isHeader
                        text: parent.index < 7 ? ["S", "M", "T", "W", "T", "F", "S"][parent.index] : ""
                        color: theme.dimText
                        font.family: theme.font
                        font.pixelSize: theme.fontSize - 2
                    }

                    Rectangle {
                        id: cell
                        anchors.fill: parent
                        visible: parent.isCell
                        radius: 6
                        color: parent.isToday ? theme.accent
                             : cellMouse.containsMouse && parent.inMonth ? theme.activeItemBg
                             : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: cell.parent.inMonth
                            text: cell.parent.day
                            color: cell.parent.isToday ? "#111111"
                                 : cell.parent.inMonth ? theme.text
                                 : theme.dimText
                            font.family: theme.font
                            font.pixelSize: theme.fontSize - 1
                            font.bold: cell.parent.isToday
                        }

                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: cell.parent.inMonth
                            onClicked: popup.monthOffset = 0
                        }
                    }
                }
            }
        }
    }
}
