import Quickshell.Services.Mpris
import QtQuick

// Shows now-playing info (title — artist) for the first active MPRIS
// player, sourced from Quickshell's built-in Mpris service. Hidden when no
// player is present. Click toggles MediaPopup.
//
// API verified against quickshell-0.3.0 qmltypes
// (Quickshell/Services/Mpris/quickshell-service-mpris.qmltypes):
//   - Mpris (singleton, `Mpris.players`) exposes `players` as an
//     UntypedObjectModel (Quickshell/ObjectModel 0.0) — `.values` is a
//     QObjectList, confirmed present on that type.
//   - MprisPlayer has `trackTitle` (QString) and `trackArtists` (QString,
//     despite the plural name — it's a bindable alias of trackArtist, NOT
//     a list). So no `.join(...)` — see Media.qml note below.
Pill {
    id: root

    // First active player, or null if nothing is playing/registered.
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    visible: player !== null

    content: Text {
        text: root.player ? (root.player.trackTitle + (root.player.trackArtists ? " — " + root.player.trackArtists : "")) : ""
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 250)
        color: theme.itemText
        font.family: theme.font
        font.pixelSize: theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            mediaPopup.visible = !mediaPopup.visible;
        }
    }
}
