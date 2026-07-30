import QtQuick
import Quickshell.Hyprland

Pill {
    id: root

    readonly property var toplevel: Hyprland.activeToplevel
    readonly property string windowTitle: toplevel && toplevel.title ? toplevel.title : ""
    readonly property string appClass: toplevel && toplevel.lastIpcObject ? (toplevel.lastIpcObject.class || "") : ""

    visible: windowTitle !== ""

    content: Row {
        spacing: 6

        Rectangle {
            visible: root.appClass !== ""
            width: classText.implicitWidth + 10
            height: classText.implicitHeight + 4
            radius: 4
            color: "#20ffffff"
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: classText
                anchors.centerIn: parent
                text: root.appClass
                font.family: theme.font
                font.pixelSize: theme.fontSize - 2
                color: theme.accent
            }
        }

        Text {
            text: root.windowTitle
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, 250)
            font.family: theme.font
            font.pixelSize: theme.fontSize
            color: theme.dimText
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
