# ── Sleep / idle-lock system (hypridle) ──
#
# Idle → lock to the ReGreet login page (greetd 0.9+ lock support: loginctl
# lock-session shows the greeter; unlocking resumes the session) → display off.
# Lid close / power key already suspend via services.logind; hypridle locks
# before sleep so waking lands on the login page.
#
# Default timeout is 5 min. Change it at runtime without a rebuild:
#   sleep-time 15      # lock after 15 min, display off after 16
#   sleep-time never   # disable idle lock (lid close still locks on suspend)
# or SUPER+S → Walker sleep menu, or SUPER+L to lock now.
# NOTE: a rebuild resets the runtime timeout to the default below.
{ config, pkgs, lib, ... }:

let
  homeDir = config.home.homeDirectory;

  # hypridle 0.1.7 syntax: `on-timeout` (hyphen), general.before_sleep_cmd.
  # This template is duplicated inside the sleep-time script (single writer at
  # runtime) — keep both in sync when changing timeouts/commands.
  mkHypridleConf = lockSec: dpmsSec: ''
    general {
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    listener {
        timeout = ${lockSec}
        on-timeout = loginctl lock-session
    }

    listener {
        timeout = ${dpmsSec}
        on-timeout = hyprctl dispatch dpms off
    }
  '';
in
{
  # Default config (5 min lock, display off +1 min). Overwritten at runtime by
  # sleep-time; next rebuild restores this default.
  home.file.".config/hypr/hypridle.conf".text = mkHypridleConf "300" "360";

  home.file.".local/bin/sleep-time" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      conf="$HOME/.config/hypr/hypridle.conf"
      arg="''${1:-5}"

      write_locked_config() {
        local lock_sec="$1" dpms_sec="$2"
        cat > "$conf" <<EOF
      general {
          before_sleep_cmd = loginctl lock-session
          after_sleep_cmd = hyprctl dispatch dpms on
      }

      listener {
          timeout = ''${lock_sec}
          on-timeout = loginctl lock-session
      }

      listener {
          timeout = ''${dpms_sec}
          on-timeout = hyprctl dispatch dpms off
      }
      EOF
      }

      case "$arg" in
        never|off|disable|0)
          cat > "$conf" <<'EOF'
      general {
          before_sleep_cmd = loginctl lock-session
          after_sleep_cmd = hyprctl dispatch dpms on
      }
      # Idle lock disabled via `sleep-time never` (lid close still locks on suspend).
      # Re-enable with sleep-time <minutes> or on next rebuild.
      EOF
          msg="Idle lock: never"
          detail="Re-enable with sleep-time <minutes> or rebuild"
          ;;
        *)
          [[ "$arg" =~ ^[0-9]+$ ]] || { echo "usage: sleep-time <minutes|never>" >&2; exit 1; }
          lock_sec=$((arg * 60))
          write_locked_config "$lock_sec" "$((lock_sec + 60))"
          msg="Idle lock: ''${arg} min"
          detail="Display off after $((arg + 1)) min"
          ;;
      esac

      systemctl --user restart hypridle 2>/dev/null || true
      notify-send -a sleep-time "$msg" "$detail" 2>/dev/null || true
    '';
  };

  # ── Walker / Elephant "Sleep time" menu (SUPER+S) ──
  home.file.".config/elephant/menus/sleep.lua".text = ''
    Name = "sleep"
    NamePretty = "Sleep time"
    Icon = "preferences-system-sleep"
    Cache = false
    Action = "sh -c '${homeDir}/.local/bin/sleep-time %VALUE%'"

    function GetEntries()
      return {
        { Text = "Never",        Subtext = "Disable idle lock (lid close still locks)", Value = "never" },
        { Text = "1 minute",     Subtext = "Lock after 1 min idle",                      Value = "1" },
        { Text = "2 minutes",    Subtext = "Lock after 2 min idle",                      Value = "2" },
        { Text = "5 minutes",    Subtext = "Lock after 5 min idle",                      Value = "5" },
        { Text = "10 minutes",   Subtext = "Lock after 10 min idle",                     Value = "10" },
        { Text = "15 minutes",   Subtext = "Lock after 15 min idle",                     Value = "15" },
        { Text = "30 minutes",   Subtext = "Lock after 30 min idle",                     Value = "30" },
        { Text = "60 minutes",   Subtext = "Lock after 1 hour idle",                     Value = "60" },
      }
    end
  '';

  # hypridle as a systemd user service (survives rebuilds, restartable from
  # sleep-time). Started explicitly from Hyprland autostart.
  systemd.user.services.hypridle = {
    Unit = {
      Description = "hypridle - idle management daemon";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.hypridle}/bin/hypridle";
      Restart = "on-failure";
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };

  home.packages = [ pkgs.hypridle ];
}
