// ── Lock service: WlSessionLock (ext-session-lock) + PAM auth ──
// Ported from Omarchy's plugins/lock, trimmed: password auth only,
// Catppuccin Mocha styling to match the old hyprlock screen.
// PAM service "hydra-lock" is provisioned system-side via security.pam.services.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME")
  readonly property string wallpaperCmd:
    "p=$(swww query 2>/dev/null | head -n1 | sed 's/.*: //'); [[ -n $p && -f $p ]] && echo $p || true"

  property bool lockRequested: false
  property bool authenticating: false
  property bool pamConfigured: false
  property string enteredPassword: ""
  property string failureMessage: ""
  property int failedAttempts: 0
  property string backgroundPath: ""
  property int backgroundVersion: 0

  readonly property bool locked: lockRequested || sessionLock.locked || sessionLock.secure

  function requestLock(reason) {
    if (!root.pamConfigured) {
      console.log("hydra lock denied: missing-pam")
      return false
    }
    if (root.locked) return true
    resetAuth()
    root.lockRequested = true
    // Blank the display only when the lock came from the idle cycle — a
    // manual SUPER+L should keep the screen lit while you step away briefly.
    if (reason === "idle") armBlankTimer()
    refreshBackground()
    sessionLock.locked = true
    console.log("hydra lock requested (" + (reason || "manual") + ")")
    return true
  }

  function finishUnlock() {
    if (!root.locked) return
    root.lockRequested = false
    resetAuth()
    idleBlankTimer.stop()
    sessionLock.locked = false
    wakeProcess.running = true
    console.log("hydra lock unlocked")
  }

  function resetAuth() {
    root.enteredPassword = ""
    root.failureMessage = ""
    root.failedAttempts = 0
    root.authenticating = false
    if (passwordPam.active) passwordPam.abort()
  }

  function refreshBackground() { readWallpaper.running = true }

  function submitPassword(value) {
    var pw = String(value || "")
    if (!root.lockRequested || root.authenticating || pw.length === 0) return
    root.pendingPassword = pw
    root.failureMessage = ""
    root.authenticating = true
    if (!passwordPam.start()) handleFailure()
  }
  property string pendingPassword: ""

  function respondToPrompt() {
    if (!root.authenticating || !passwordPam.active || !passwordPam.responseRequired) return
    passwordPam.respond(root.pendingPassword)
  }

  function handleFailure() {
    if (!root.lockRequested) return
    root.authenticating = false
    root.enteredPassword = ""
    root.pendingPassword = ""
    root.failedAttempts += 1
    root.failureMessage = "Authentication failed (" + root.failedAttempts + ")"
    wakeProcess.running = true
    armBlankTimer()
  }

  // ── Display blanking while locked (brightness instead of dpms, like Omarchy) ──
  function armBlankTimer() {
    idleBlankTimer.armedAt = Date.now()
    idleBlankTimer.restart()
  }

  Timer {
    id: idleBlankTimer
    interval: 5000
    property double armedAt: 0
    onTriggered: {
      // Frozen countdown firing after resume would blank a fresh unlock screen.
      if (Date.now() - armedAt > interval + 2000) { armBlankTimer(); return }
      if (root.lockRequested && !root.authenticating) blankProcess.running = true
    }
  }
  Process {
    id: blankProcess
    // Save current brightness then drop to 0; wakeProcess restores via -r.
    command: ["bash", "-c", "brightnessctl -q -s set 0 2>/dev/null || true"]
  }
  Process {
    id: wakeProcess
    command: ["bash", "-c", "brightnessctl -q -r 2>/dev/null || true"]
  }

  // ── Session lock ──
  WlSessionLock {
    id: sessionLock
    locked: false
    onSecureStateChanged: console.log("hydra lock secure=" + secure)
    onLockStateChanged: {
      if (!locked && root.lockRequested) {
        // Compositor dropped the lock under us (crash/restart).
        root.lockRequested = false
        root.resetAuth()
      }
    }

    WlSessionLockSurface {
      id: surface
      color: "#1e1e2e"

      LockView {
        anchors.fill: parent
        backgroundPath: root.backgroundPath
        backgroundVersion: root.backgroundVersion
        authenticating: root.authenticating
        failureMessage: root.failureMessage
        failedAttempts: root.failedAttempts
        inputEnabled: root.lockRequested
        loadBackground: root.locked
        passwordText: root.enteredPassword
        onPasswordTextEdited: function(pw) { root.enteredPassword = pw }
        onSubmitPassword: function(pw) { root.submitPassword(pw) }
        onClearFailureRequested: root.failureMessage = ""
      }
    }
  }

  // ── PAM ──
  PamContext {
    id: passwordPam
    config: "hydra-lock"
    user: root.userName

    onResponseRequiredChanged: root.respondToPrompt()
    onPamMessage: root.respondToPrompt()

    onCompleted: function(result) {
      root.authenticating = false
      root.pendingPassword = ""
      if (!root.lockRequested) return
      if (result === PamResult.Success) root.finishUnlock()
      else root.handleFailure()
    }

    onError: function(error) { root.handleFailure() }
  }

  Process {
    id: pamCheckProc
    command: ["bash", "-c", "[[ -f /etc/pam.d/hydra-lock ]] && echo yes || echo no"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.pamConfigured = String(text).trim() === "yes"
    }
  }

  Process {
    id: readWallpaper
    command: ["bash", "-c", root.wallpaperCmd]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = String(text || "").trim()
        if (next !== root.backgroundPath) {
          root.backgroundPath = next
          root.backgroundVersion += 1
        }
      }
    }
  }

  Component.onCompleted: pamCheckProc.running = true

  IpcHandler {
    target: "lock"
    function lock(): string {
      if (!root.pamConfigured) return "missing-pam"
      if (!root.locked && !root.requestLock()) return "failed"
      return "ok"
    }
    function isLocked(): string { return root.locked ? "true" : "false" }
    function status(): string {
      return JSON.stringify({
        locked: root.locked, requested: root.lockRequested,
        secure: sessionLock.secure, pam: root.pamConfigured,
        authenticating: root.authenticating, failedAttempts: root.failedAttempts
      })
    }
  }
}
