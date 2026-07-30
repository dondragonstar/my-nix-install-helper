import QtQuick

// Shows screen backlight brightness percentage, sourced from the
// BacklightSvc service.
Pill {
    content: Text {
        text: "󰃠 " + backlight.pct + "%"
        color: theme.text
        font.family: theme.font
        font.pixelSize: theme.fontSize
    }
}
