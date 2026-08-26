# ── Omarchy-style screensaver + lock system (quickshell) ──
#
# Replaces the hypridle+hyprlock stack with a standalone Quickshell shell
# (/etc/nixos/quickshell-lock) that owns the whole idle pipeline, ported from
# basecamp/omarchy:
#
#   idle-notify → screensaver (ttfx ascii effects, fullscreen terminals)
#               → lock (WlSessionLock ext-session-lock + PAM "hydra-lock")
#               → display blank (brightness 0, not dpms)
#   suspend     → systemd-inhibit delay + PrepareForSleep watcher locks and
#                 polls until the session reports secure before logind sleeps
#
# Scripts are embedded with quoted heredocs (<<'EOF') so bash ${} stays bash.
{ config, pkgs, lib, ... }:

let
  homeDir = config.home.homeDirectory;
  qsShellDir = "${homeDir}/.config/quickshell-lock";

  scriptPath = lib.makeBinPath [
    pkgs.quickshell
    pkgs.jq
    pkgs.dbus
    pkgs.util-linux
    pkgs.procps
    pkgs.libnotify
    pkgs.brightnessctl
    pkgs.coreutils
    pkgs.bash
  ];

  hydraScripts = pkgs.runCommand "hydra-scripts" { }
    ''
      mkdir -p $out/bin

      cat > $out/bin/hydra-screensaver <<'EOF'
      #!/usr/bin/env bash
      # Screensaver renderer: loops ttfx random effects over the branding art.
      # Runs inside a fullscreen terminal of class org.hydra.screensaver;
      # exits on any key/mouse input or when the window loses focus.
      set -u

      art="$HOME/.config/branding/screensaver.txt"
      [[ -f $art ]] || exit 0

      exit_screensaver() {
        hyprctl eval 'hl.config({ cursor = { invisible = false } })' &>/dev/null \
          || hyprctl keyword cursor:invisible false &>/dev/null || true
        pkill -x ttfx 2>/dev/null
        pkill -f '[o]rg.hydra.screensaver' 2>/dev/null
        exit 0
      }
      trap exit_screensaver SIGINT SIGTERM SIGHUP SIGQUIT

      printf '\033]11;rgb:00/00/00\007'
      hyprctl eval 'hl.config({ cursor = { invisible = true } })' &>/dev/null \
        || hyprctl keyword cursor:invisible true &>/dev/null

      tty_dev=$(tty 2>/dev/null)

      # ttfx sizes its canvas at startup; wait for the compositor resize to land.
      wait_for_resize() {
        local deadline=$((SECONDS + 2))
        while ((SECONDS < deadline)) && [[ $(stty size 2>/dev/null) == "24 80" ]]; do
          sleep 0.02
        done
      }

      in_focus() {
        hyprctl activewindow -j 2>/dev/null | grep -q '"class": *"org.hydra.screensaver"'
      }

      wait_for_resize
      while true; do
        ttfx -i "$art" --frame-rate 120 --canvas-width 0 --canvas-height 0 \
          --reuse-canvas --anchor-canvas c --anchor-text c --random-effect \
          --no-eol --no-restore-cursor &
        while pgrep -t "''${tty_dev#/dev/}" -x ttfx >/dev/null; do
          if read -rn1 -t1 _ || ! in_focus; then
            exit_screensaver
          fi
        done
      done
      EOF

      cat > $out/bin/hydra-launch-screensaver <<'EOF'
      #!/usr/bin/env bash
      # Spawn one fullscreen alacritty per monitor running the screensaver.
      set -u

      pgrep -f '[o]rg.hydra.screensaver' >/dev/null && exit 0
      command -v alacritty >/dev/null || exit 0
      command -v socat >/dev/null || true

      focused=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name')
      sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

      focus_mon() { hyprctl dispatch focusmonitor "$1" >/dev/null 2>&1; }

      exec {events}< <(socat -U - "UNIX-CONNECT:$sock" 2>/dev/null)

      wait_for_window() {
        local line deadline=$((SECONDS + 5))
        [[ -e /proc/$$/fd/$events ]] || { sleep 0.7; return 0; }
        while ((SECONDS < deadline)) && IFS= read -r -t "$((deadline - SECONDS))" -u "$events" line; do
          [[ $line == openwindow\>\>*,org.hydra.screensaver,* ]] && return 0
        done
      }

      for m in $(hyprctl monitors -j 2>/dev/null | jq -r '.[] | .name'); do
        focus_mon "$m"
        alacritty --class org.hydra.screensaver \
          -o font.size=16 -o window.padding.x=0 -o window.padding.y=0 \
          -o window.decorations=None -e hydra-screensaver >/dev/null 2>&1 &
        wait_for_window
      done

      [[ -n $focused ]] && focus_mon "$focused"
      EOF

      cat > $out/bin/hydra-system-lock <<'EOF'
      #!/usr/bin/env bash
      # Lock now: session lock via the quickshell shell + housekeeping.
      set -u

      qs ipc -p "$HOME/.config/quickshell-lock" call -- lock lock >/dev/null 2>&1
      rc=$?

      # Reset keyboard layout to the first entry so the password always types.
      hyprctl switchxkblayout all 0 >/dev/null 2>&1

      # A running screensaver fights the lock surface — tear it down.
      pkill -x ttfx 2>/dev/null || true
      pkill -f '[o]rg.hydra.screensaver' 2>/dev/null || true

      exit $rc
      EOF

      cat > $out/bin/hydra-system-wake <<'EOF'
      #!/usr/bin/env bash
      # Wake displays: restore brightness after idle/suspend.
      brightnessctl -qr restore 2>/dev/null || true
      EOF

      cat > $out/bin/hydra-system-sleep-lock <<'EOF'
      #!/usr/bin/env bash
      # Lock before suspend and poll until the session lock is SECURE.
      # Ported from omarchy-system-sleep-lock: logind stops honouring the delay
      # inhibitor after InhibitDelayMaxUSec, so every step is bounded by what is
      # left of the budget — the deadline enforces itself.
      budget_cap_ms=12000
      lock_timeout_ms=1000
      status_timeout_ms=500
      poll_interval=0.1

      derive_budget_ms() {
        local window
        window=$(timeout --kill-after=0.1s 1s busctl get-property \
          org.freedesktop.login1 /org/freedesktop/login1 \
          org.freedesktop.login1.Manager InhibitDelayMaxUSec 2>/dev/null)
        window=''${window##* }

        [[ $window =~ ^[0-9]+$ ]] && (( window > 0 )) || window=5000000
        window=$((window / 1000))
        window=$((window - (window / 5 > 1000 ? window / 5 : 1000)))
        (( window < budget_cap_ms )) && echo "$window" || echo "$budget_cap_ms"
      }

      budget_ms=$(derive_budget_ms)
      deadline_ms=$((10#''${EPOCHREALTIME//[!0-9]/} / 1000 + budget_ms))

      remaining_ms() {
        echo $((deadline_ms - 10#''${EPOCHREALTIME//[!0-9]/} / 1000))
      }

      ipc() {
        local limit=$1 remaining seconds
        shift
        remaining=$(remaining_ms)
        (( remaining > 0 )) || return 1
        (( limit < remaining )) || limit=$remaining
        printf -v seconds '%d.%03d' $((limit / 1000)) $((limit % 1000))
        timeout --kill-after=0.1s "$seconds" \
          qs ipc -p "$HOME/.config/quickshell-lock" call -- "$@" 2>/dev/null
      }

      report_unsecured() {
        printf 'hydra-system-sleep-lock: suspending without a secure lock (%s)\n' "$1" >&2
        notify-send -u critical -a hydra-lock "Screen did not lock before suspend" \
          "The session was left unlocked ($1)." >/dev/null 2>&1 || true
        exit 1
      }

      request_lock() {
        case $(ipc "$lock_timeout_ms" lock lock) in
          missing-pam) report_unsecured "no PAM config for hydra-lock" ;;
        esac
      }

      lock_state() {
        jq -r 'if .secure == true then "secure"
               elif .requested == true or .locked == true then "locking"
               else "idle" end' \
          <<<"$(ipc "$status_timeout_ms" lock status)" 2>/dev/null
      }

      request_lock

      while (( $(remaining_ms) > 0 )); do
        case $(lock_state) in
          secure) exit 0 ;;
          locking) ;;
          *) request_lock ;;
        esac
        sleep "$poll_interval"
      done

      report_unsecured "lock did not secure within ''${budget_ms}ms"
      EOF

      cat > $out/bin/hydra-system-sleep-monitor <<'EOF'
      #!/usr/bin/env bash
      # Run under systemd-inhibit --what=sleep --mode=delay; on logind's
      # PrepareForSleep(true) hand off to the bounded sleep-lock script.
      set -u

      consume_sleep_events() {
        local line
        while IFS= read -r line; do
          if [[ $line == *"boolean true"* ]]; then
            hydra-system-sleep-lock
            return $?
          fi
        done
      }

      monitor_sleep_events() {
        local fd pid status
        coproc SLEEP_EVENTS {
          exec dbus-monitor --system \
            "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"
        }
        fd=''${SLEEP_EVENTS[0]}
        pid=$SLEEP_EVENTS_PID

        cleanup() {
          kill "$pid" 2>/dev/null || true
          wait "$pid" 2>/dev/null || true
        }
        trap cleanup EXIT

        consume_sleep_events <&"$fd"
        status=$?
        cleanup
        trap - EXIT
        return "$status"
      }

      case ''${1:-} in
        --consume) consume_sleep_events; exit $? ;;
        --inhibited) monitor_sleep_events; exit $? ;;
      esac

      exec systemd-inhibit \
        --what=sleep \
        --mode=delay \
        --who=Hydra \
        --why="Lock screen before suspend" \
        "$0" --inhibited
      EOF

      cat > $out/bin/sleep-time <<'EOF'
      #!/usr/bin/env bash
      # Runtime idle-timeout control (SUPER+S walker menu). Writes the JSON
      # config the quickshell lock shell live-reloads:
      #   sleep-time 15      screensaver at ~12.5 min, lock after 15 min
      #   sleep-time never   disable idle cycle (lid close still locks)
      set -euo pipefail

      arg="''${1:-5}"
      conf="$HOME/.config/hypr/idle.json"
      mkdir -p "$(dirname "$conf")"

      case "$arg" in
        never|off|disable|0)
          printf '{"never": true}\n' > "$conf"
          msg="Idle lock: never"
          detail="Re-enable with sleep-time <minutes>"
          ;;
        *)
          [[ "$arg" =~ ^[0-9]+$ ]] || { echo "usage: sleep-time <minutes|never>" >&2; exit 1; }
          lock=$((arg * 60))
          ss=$((lock - 150)); (( ss < 30 )) && ss=30
          printf '{"screensaver": %d, "lock": %d}\n' "$ss" "$lock" > "$conf"
          msg="Idle lock: ''${arg} min"
          detail="Screensaver after $(( (ss + 30) / 60 )) min, display off when locked"
          ;;
      esac

      # Live reload covers a running shell; never bounce it while locked.
      if [[ $(qs ipc -p "$HOME/.config/quickshell-lock" call -- lock isLocked 2>/dev/null) != "true" ]]; then
        systemctl --user try-restart hydra-lock-shell 2>/dev/null || true
      fi
      notify-send -a sleep-time "$msg" "$detail" 2>/dev/null || true
      EOF

      chmod +x $out/bin/*
    '';
in
{  # Runtime deps of the embedded scripts (they run from keybinds, Hyprland,
  # and systemd user units — all need a predictable PATH).
  home.packages = [
    (pkgs.callPackage ../../pkgs/ttfx.nix { })
    hydraScripts
    pkgs.jq
    pkgs.socat
    pkgs.dbus
    pkgs.util-linux
    pkgs.procps
    pkgs.libnotify
    pkgs.brightnessctl
  ];

  # ── Quickshell lock/idle shell instance ──
  home.file.".config/quickshell-lock" = {
    source = ../../quickshell-lock;
    recursive = true;
  };

  systemd.user.services.hydra-lock-shell = {
    Unit = {
      Description = "Hydra lock/idle shell (screensaver + session lock)";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      Environment = "PATH=${scriptPath}";
      ExecStart = "${pkgs.quickshell}/bin/qs -p ${qsShellDir}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };

  # ── Sleep-lock watcher: holds a delay inhibitor, locks on PrepareForSleep ──
  systemd.user.services.hydra-sleep-lock = {
    Unit = {
      Description = "Lock Hydra session before suspend";
      After = [ "dbus.socket" ];
      Requires = [ "dbus.socket" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = [ "WAYLAND_DISPLAY" ];
    };
    Service = {
      Type = "simple";
      Environment = "PATH=${scriptPath}";
      ExecStart = "${homeDir}/.local/bin/hydra-system-sleep-monitor";
      Restart = "always";
      RestartSec = 2;
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };

  # Seed runtime files only when absent — user-owned, editable without rebuilds.
  home.activation.seedHydraLock =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Idle timeouts config consumed live by the quickshell shell.
      idleJson="${homeDir}/.config/hypr/idle.json"
      if [ ! -e "$idleJson" ]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$idleJson")"
        $DRY_RUN_CMD printf '{"screensaver":150,"lock":300}\n' > "$idleJson"
        $DRY_RUN_CMD chmod 644 "$idleJson"
      fi

      # Screensaver ascii art (NixOS snowflake). Swap this file for any art.
      art="${homeDir}/.config/branding/screensaver.txt"
      if [ ! -e "$art" ]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$art")"
        $DRY_RUN_CMD cat ${./branding/nixos-snowflake.txt} > "$art"
        $DRY_RUN_CMD chmod 644 "$art"
      fi
    '';

  # Convenience for testing from a terminal.
  home.sessionVariables.HYDRA_LOCK_SHELL = qsShellDir;
}
