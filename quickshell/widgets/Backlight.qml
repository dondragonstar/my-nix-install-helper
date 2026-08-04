import QtQuick
import Quickshell.Io

// Shows screen backlight brightness percentage, sourced from the
// BacklightSvc service. Scroll to change brightness via brightnessctl.
Pill {
    Process {
        id: blProc
        command: ["brightnessctl", "set", "5%+"]
    }

    content: Text {
        text: "󰃠 " + backlight.pct + "%"
        color: theme.text
        font.family: theme.font
        font.pixelSize: theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onWheel: function(wheel) {
            var dy = wheel.angleDelta.y;
            if (dy === 0)
                dy = wheel.pixelDelta.y;
            if (dy === 0)
                return;
            blProc.command = ["brightnessctl", "set", dy > 0 ? "5%+" : "5%-"];
            blProc.running = true;
        }
    }
}
