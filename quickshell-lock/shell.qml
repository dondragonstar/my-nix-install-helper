//@ pragma UseQApplication
// ── Hydra lock/idle shell ──
//
// Standalone Quickshell instance (separate from the bar) modeled on Omarchy:
//   IdleMonitor (Wayland idle-notify)  → screensaver → lock → display blank
//   WlSessionLock + PAM                → real ext-session-lock screen
// IPC: quickshell ipc -p ~/.config/quickshell-lock call -- <target> <fn>
//   idle   status | toggle | enable | disable
//   lock   lock | isLocked | status
import QtQuick
import Quickshell

ShellRoot {
  IdleService { id: idle }
  LockService { id: lockSvc }
}
