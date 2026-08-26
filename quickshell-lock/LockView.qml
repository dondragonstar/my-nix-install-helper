// ── Lock screen view: Catppuccin Mocha, mirrors the retired hyprlock layout ──
// Blurred wallpaper, big clock, date, greeting, translucent pill password field.
import QtQuick
import QtQuick.Effects

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool authenticating: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false
  property date clockDate: new Date()

  readonly property string fontName: "JetBrainsMono Nerd Font"
  // Catppuccin Mocha
  readonly property color cBase: "#1e1e2e"
  readonly property color cBlue: "#89b4fa"
  readonly property color cRed: "#f38ba8"
  readonly property color cText: "#cdd6f4"
  readonly property color cSubtext: "#a6adc8"

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: if (inputEnabled) Qt.callLater(function() { passwordInput.forceActiveFocus() })
  Component.onCompleted: syncPasswordText()

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.clockDate = new Date()
  }

  Rectangle {
    anchors.fill: parent
    color: root.cBase

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground && root.backgroundPath ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 1.0
      blurMax: 96
      blurMultiplier: 1.2
      brightness: -0.15
      contrast: -0.05
    }

    Column {
      anchors.centerIn: parent
      spacing: 18

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(root.clockDate, "HH:mm")
        color: root.cText
        font.family: root.fontName
        font.pixelSize: 95
        font.weight: Font.DemiBold
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(root.clockDate, "dddd, dd MMMM")
        color: root.cSubtext
        font.family: root.fontName
        font.pixelSize: 26
      }
      Item { width: 1; height: 30 }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Welcome back, hydragon2000"
        color: root.cSubtext
        font.family: root.fontName
        font.pixelSize: 18
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 300
        height: 55
        radius: 16
        color: "#cc313244"
        border.width: 3
        border.color: root.failureMessage.length > 0 ? root.cRed : root.cBlue

        TextInput {
          id: passwordInput
          anchors.fill: parent
          anchors.leftMargin: 18
          anchors.rightMargin: 18
          verticalAlignment: TextInput.AlignVCenter
          horizontalAlignment: TextInput.AlignHCenter
          clip: true
          enabled: root.inputEnabled && !root.authenticating
          readOnly: root.authenticating
          echoMode: TextInput.Password
          passwordCharacter: "\u25CF"
          color: root.cText
          selectionColor: root.cBlue
          selectedTextColor: root.cBase
          font.family: root.fontName
          font.pixelSize: 22

          onTextChanged: {
            if (!root.syncingPasswordText) root.passwordTextEdited(text)
            if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
          }
          onAccepted: {
            var submitted = text
            root.passwordTextEdited("")
            if (submitted.length > 0) root.submitPassword(submitted)
          }
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
              root.passwordTextEdited("")
              event.accepted = true
            }
          }
        }

        Text {
          anchors.fill: passwordInput
          text: root.authenticating ? "Checking…"
              : (root.failureMessage.length > 0 ? root.failureMessage : "Password…")
          visible: passwordInput.text.length === 0
          color: root.failureMessage.length > 0 ? root.cRed : root.cSubtext
          font.family: root.fontName
          font.pixelSize: 20
          font.italic: root.failureMessage.length === 0
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: passwordInput.forceActiveFocus()
    }
  }
}
