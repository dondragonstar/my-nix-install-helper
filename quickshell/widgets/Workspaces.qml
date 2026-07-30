import QtQuick
import Quickshell.Hyprland

Row {
    id: root
    spacing: 4

    readonly property int workspaceCount: 5

    readonly property int activeWorkspaceId: {
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace)
            return Hyprland.focusedMonitor.activeWorkspace.id;
        if (Hyprland.focusedWorkspace)
            return Hyprland.focusedWorkspace.id;
        return -1;
    }

    Repeater {
        model: root.workspaceCount

        delegate: Rectangle {
            id: wsButton

            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: wsId === root.activeWorkspaceId

            width: active ? 28 : 10
            height: active ? theme.barHeight - theme.itemMargin * 2 : 10
            radius: active ? theme.radius : 5
            color: active ? theme.activeItemBg : theme.dimText

            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            Behavior on width {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on radius {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 200 }
            }

            Text {
                anchors.centerIn: parent
                text: wsButton.wsId
                font.family: theme.font
                font.pixelSize: theme.fontSize - 1
                color: theme.activeText
                visible: wsButton.active
                opacity: wsButton.active ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + wsButton.wsId)
            }
        }
    }
}
