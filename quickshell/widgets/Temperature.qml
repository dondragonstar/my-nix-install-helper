import QtQuick

Pill {
    content: Text {
        text: "󰔏 " + sysinfo.tempC + "°C"
        color: sysinfo.tempC >= 85 ? theme.critical
             : sysinfo.tempC >= 70 ? theme.warning
             : theme.text
        font.family: theme.font
        font.pixelSize: theme.fontSize
    }
}
