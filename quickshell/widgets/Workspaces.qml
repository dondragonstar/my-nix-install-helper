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

    function workspaceHasWindows(wsId) {
        var wsList = Hyprland.workspaces;
        if (!wsList || !wsList.values) return false;
        for (var i = 0; i < wsList.values.length; i++) {
            var ws = wsList.values[i];
            if (ws.id === wsId && ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0)
                return true;
        }
        return false;
    }

    function getWorkspaceApps(wsId) {
        var wsList = Hyprland.workspaces;
        if (!wsList || !wsList.values) return [];
        for (var i = 0; i < wsList.values.length; i++) {
            var ws = wsList.values[i];
            if (ws.id === wsId && ws.toplevels && ws.toplevels.values) {
                var apps = [];
                for (var j = 0; j < ws.toplevels.values.length; j++) {
                    var tl = ws.toplevels.values[j];
                    var appName = "";
                    if (tl.lastIpcObject) appName = tl.lastIpcObject.class || "";
                    if (!appName && tl.title) appName = tl.title;
                    if (appName) apps.push(appName);
                }
                return apps;
            }
        }
        return [];
    }

    Repeater {
        model: root.workspaceCount

        delegate: Rectangle {
            id: wsButton

            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: wsId === root.activeWorkspaceId
            readonly property bool occupied: root.workspaceHasWindows(wsId)
            readonly property var apps: wsArea.containsMouse ? root.getWorkspaceApps(wsId) : []

            width: 28
            height: theme.barHeight - theme.itemMargin * 2
            radius: theme.radius
            color: active ? theme.accent
                 : occupied ? theme.activeItemBg
                 : "#20ffffff"

            anchors.verticalCenter: parent ? parent.verticalCenter : undefined

            Behavior on color {
                ColorAnimation { duration: 200 }
            }

            Text {
                anchors.centerIn: parent
                text: wsButton.wsId
                font.family: theme.font
                font.pixelSize: theme.fontSize - 1
                font.bold: wsButton.active
                color: wsButton.active ? "#111111"
                     : wsButton.occupied ? theme.activeText
                     : theme.dimText
            }

            Rectangle {
                visible: wsButton.occupied && !wsButton.active
                width: 4
                height: 4
                radius: 2
                color: theme.accent
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
            }

            MouseArea {
                id: wsArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("workspace " + wsButton.wsId)
            }

            Rectangle {
                id: wsTooltip
                visible: wsArea.containsMouse && wsButton.apps.length > 0
                width: tooltipCol.implicitWidth + 16
                height: tooltipCol.implicitHeight + 12
                color: theme.popupBg
                border.color: theme.border
                border.width: 1
                radius: 8
                x: -width / 2 + parent.width / 2
                y: parent.height + 6
                z: 100

                Column {
                    id: tooltipCol
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: wsButton.apps
                        delegate: Text {
                            text: modelData
                            color: theme.text
                            font.family: theme.font
                            font.pixelSize: theme.fontSize - 2
                        }
                    }
                }
            }
        }
    }
}
