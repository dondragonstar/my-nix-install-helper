// ── Idle service: idle-notify → screensaver → lock cycle ──
// Ported from Omarchy's plugins/services/idle. Config comes from
// ~/.config/hypr/idle.json ({"screensaver":sec,"lock":sec} or {"never":true}),
// written by the `sleep-time` script; live-reloaded via FileView watch.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDir: home + "/.local/state/hydra"
  readonly property string stayAwakePath: stateDir + "/stay-awake"
  readonly property string configPath: home + "/.config/hypr/idle.json"
  readonly property string screensaverClass: "org.hydra.screensaver"

  // Defaults mirror Omarchy: screensaver 2.5 min, lock 5 min.
  readonly property int defaultScreensaverSeconds: 150
  readonly property int defaultLockSeconds: 300

  property int screensaverTimeoutSeconds: defaultScreensaverSeconds
  property bool screensaverDisabled: false
  property int lockTimeoutSeconds: defaultLockSeconds
  property bool neverIdle: false
  property bool stayAwake: false
  property bool configLoaded: false
  property bool stateLoaded: false

  readonly property bool idleEnabled: configLoaded && !neverIdle && !stayAwake
  readonly property int firstIdleTimeoutSeconds: Math.min(screensaverTimeoutSeconds, lockTimeoutSeconds)
  readonly property int screensaverDelaySeconds: Math.max(0, screensaverTimeoutSeconds - firstIdleTimeoutSeconds)
  readonly property int lockDelaySeconds: Math.max(0, lockTimeoutSeconds - firstIdleTimeoutSeconds)

  property bool idledThisCycle: false
  property bool screensaverStartedThisCycle: false
  property var screensaverWindows: ({})
  property int screensaverWindowCount: 0

  function launchScreensaver() {
    root.screensaverStartedThisCycle = true
    screensaverLaunchGraceTimer.restart()
    if (!screensaverProcess.running) {
      screensaverProcess.command = ["bash", "-lc",
        "[[ $(qs ipc -p " + root.home + "/.config/quickshell-lock call -- lock isLocked 2>/dev/null) == 'true' ]] || hydra-launch-screensaver"]
      screensaverProcess.running = true
    }
  }

  function lockSystem(reason) {
    console.log("hydra idle lock-system:", reason || "requested")
    screensaverTimer.stop()
    lockTimer.stop()
    screensaverLaunchGraceTimer.stop()
    root.idledThisCycle = false
    root.screensaverStartedThisCycle = false
    resetScreensaverWindows()
    lockSvc.requestLock("idle")
  }

  function startIdleCycle() {
    if (root.idledThisCycle) return
    console.log("hydra idle cycle-start ss=" + root.screensaverTimeoutSeconds + "s lock=" + root.lockTimeoutSeconds + "s")
    root.idledThisCycle = true
    root.screensaverStartedThisCycle = false
    resetScreensaverWindows()

    if (root.screensaverDisabled || root.screensaverDelaySeconds === 0) {
      if (!root.screensaverDisabled) launchScreensaver()
    } else screensaverTimer.restart()

    if (root.lockDelaySeconds === 0) lockSystem("lock-immediate")
    else lockTimer.restart()
  }

  function cancelIdleCycle(reason) {
    if (!root.idledThisCycle) return
    console.log("hydra idle cycle-cancel:", reason || "activity")
    screensaverTimer.stop()
    lockTimer.stop()
    screensaverLaunchGraceTimer.stop()
    wakeProcess.running = true
    root.idledThisCycle = false
    root.screensaverStartedThisCycle = false
    resetScreensaverWindows()
  }

  function resetScreensaverWindows() {
    root.screensaverWindows = ({})
    root.screensaverWindowCount = 0
  }

  function setScreensaverWindow(address, opened) {
    var next = {}
    for (var k in root.screensaverWindows) next[k] = true
    if (opened) next[address] = true
    else delete next[address]
    var count = 0
    for (var k2 in next) count++
    root.screensaverWindows = next
    root.screensaverWindowCount = count

    if (opened) {
      screensaverLaunchGraceTimer.stop()
    } else if (root.idleEnabled && root.idledThisCycle && root.screensaverStartedThisCycle && count === 0) {
      // User dismissed the screensaver before the lock deadline → treat as activity.
      cancelIdleCycle("screensaver-dismissed")
    }
  }

  function handleHyprlandEvent(event) {
    var name = String(event && event.name ? event.name : "")
    if (name === "openwindow") {
      var p = String(event.data || "").split(",")
      if (String(p[2] || "") === root.screensaverClass) setScreensaverWindow(String(p[0]), true)
    } else if (name === "closewindow") {
      var addr = String(event.data || "").split(",")[0]
      if (root.screensaverWindows[addr]) setScreensaverWindow(addr, false)
    }
  }

  function handleActive() {
    if (!root.idledThisCycle) return
    // Screensaver startup can report activity; keep the cycle armed while it lives.
    if (root.screensaverStartedThisCycle && (root.screensaverWindowCount > 0 || screensaverLaunchGraceTimer.running)) return
    cancelIdleCycle("activity")
  }

  function applyConfig(jsonText) {
    try {
      var c = JSON.parse(String(jsonText))
      root.neverIdle = c.never === true
      if (typeof c.lock === "number" && c.lock > 0) root.lockTimeoutSeconds = c.lock
      // screensaver <= 0 (or null): no screensaver, lock still armed.
      root.screensaverDisabled = !(typeof c.screensaver === "number" && c.screensaver > 0)
      if (!root.screensaverDisabled) root.screensaverTimeoutSeconds = c.screensaver
    } catch (e) {
      console.log("hydra idle bad config:", e)
    }
  }

  // ── Idle detection ──
  IdleMonitor {
    id: idleMonitor
    enabled: root.idleEnabled
    timeout: root.firstIdleTimeoutSeconds
    respectInhibitors: true
    onIsIdleChanged: isIdle ? root.startIdleCycle() : root.handleActive()
  }

  Timer { id: screensaverTimer; interval: root.screensaverDelaySeconds * 1000; onTriggered: root.launchScreensaver() }
  Timer {
    id: lockTimer
    interval: root.lockDelaySeconds * 1000
    onTriggered: if (root.idleEnabled && root.idledThisCycle) root.lockSystem("lock-timeout")
  }
  Timer {
    id: screensaverLaunchGraceTimer
    interval: 3000
    onTriggered: {
      if (root.idleEnabled && root.idledThisCycle && root.screensaverStartedThisCycle
          && root.screensaverWindowCount === 0 && !idleMonitor.isIdle)
        root.cancelIdleCycle("screensaver-not-running")
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.handleHyprlandEvent(event) }
  }

  Process { id: screensaverProcess }
  Process {
    id: wakeProcess
    command: ["bash", "-c", "brightnessctl -q -r 2>/dev/null || true"]
  }

  // ── Config + stay-awake state: FileView watches, Process re-reads ──
  FileView { path: root.configPath; watchChanges: true; onFileChanged: readConfig.running = true }
  FileView { path: root.stayAwakePath; watchChanges: true; onFileChanged: readStayAwake.running = true }

  Process {
    id: readConfig
    command: ["bash", "-c", "cat '" + root.configPath + "' 2>/dev/null || echo '{}'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyConfig(text)
    }
    onExited: root.configLoaded = true
  }

  Process {
    id: readStayAwake
    command: ["bash", "-c", "[[ -f '" + root.stayAwakePath + "' ]] && echo yes || echo no"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.stayAwake = String(text).trim() === "yes"
    }
    onExited: root.stateLoaded = true
  }

  Component.onCompleted: {
    readConfig.running = true
    readStayAwake.running = true
  }

  IpcHandler {
    target: "idle"
    function status(): string {
      return JSON.stringify({
        enabled: root.idleEnabled, never: root.neverIdle, stayAwake: root.stayAwake,
        inCycle: root.idledThisCycle,
        screensaver: root.screensaverDisabled ? null : root.screensaverTimeoutSeconds,
        lock: root.lockTimeoutSeconds, screensaverWindows: root.screensaverWindowCount
      })
    }
    function toggle(): string {
      toggleProc.command = ["bash", "-c",
        "mkdir -p '" + root.stateDir + "' && " + (root.stayAwake ? "rm -f " : "touch ") + "'" + root.stayAwakePath + "'"]
      toggleProc.running = true
      return root.stayAwake ? "idle-enabled" : "stay-awake"
    }
  }
  Process { id: toggleProc }
}
