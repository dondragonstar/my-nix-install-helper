# ── Sleep / idle-lock system (hypridle + hyprlock) ──
#
# Idle → hyprlock (Hyprland lock screen) → display off. Lid close / power key
# suspend via services.logind; hypridle runs hyprlock before sleep so waking
# lands on the lock screen. SUPER+L locks now; SUPER+S opens the sleep menu.
#
# Default timeout is 5 min. Change it at runtime without a rebuild:
#   sleep-time 15      # lock after 15 min, display off after 16
#   sleep-time never   # disable idle lock (lid close still locks on suspend)
# The sleep-time script OWNS ~/.config/hypr/hypridle.conf (no longer HM-managed),
# so runtime choices persist across rebuilds. A home.activation seeder writes the
# 5-min default only when the file is missing (fresh profile).
{ config, pkgs, lib, ... }:

let
  homeDir = config.home.homeDirectory;

  # hypridle 0.1.7 syntax: `on-timeout` (hyphen), general.before_sleep_cmd.
  # This template is duplicated inside the sleep-time script (single writer at
  # runtime) — keep both in sync when changing timeouts/commands.
  mkHypridleConf = lockSec: dpmsSec: ''
    general {
        lock_cmd = hyprlock
        before_sleep_cmd = hyprlock
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    listener {
        timeout = ${lockSec}
        on-timeout = hyprlock
    }

    listener {
        timeout = ${dpmsSec}
        on-timeout = hyprctl dispatch dpms off
    }
  '';

  # Nix-store copy of the default config; seeded to the runtime path if absent.
  defaultHypridleConf = pkgs.writeText "hypridle-default.conf" (mkHypridleConf "300" "360");
in
{
  # sleep-time owns ~/.config/hypr/hypridle.conf. Seed the default only when the
  # file does not yet exist (fresh HOME) or is still an HM-managed store symlink
  # from a pre-hyprlock generation (writing through it would hit the read-only
  # store path — the trap this change exists to retire). Never clobber a
  # regular runtime file that sleep-time wrote.
  home.activation.seedHypridleConf =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      hypridleConf="${homeDir}/.config/hypr/hypridle.conf"
      if [ ! -e "$hypridleConf" ] || [ -L "$hypridleConf" ]; then
        $DRY_RUN_CMD rm -f "$hypridleConf"
        $DRY_RUN_CMD mkdir -p "$(dirname "$hypridleConf")"
        $DRY_RUN_CMD cp ${defaultHypridleConf} "$hypridleConf"
        $DRY_RUN_CMD chmod 644 "$hypridleConf"
      fi
    '';

  home.file.".local/bin/sleep-time" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      conf="$HOME/.config/hypr/hypridle.conf"
      arg="''${1:-5}"

      mkdir -p "$(dirname "$conf")"

      write_locked_config() {
        local lock_sec="$1" dpms_sec="$2"
        cat > "$conf" <<EOF
      general {
          lock_cmd = hyprlock
          before_sleep_cmd = hyprlock
          after_sleep_cmd = hyprctl dispatch dpms on
      }

      listener {
          timeout = ''${lock_sec}
          on-timeout = hyprlock
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
          lock_cmd = hyprlock
          before_sleep_cmd = hyprlock
          after_sleep_cmd = hyprctl dispatch dpms on
      }
      # Idle lock disabled via `sleep-time never` (lid close still locks on suspend).
      # Re-enable with sleep-time <minutes>.
EOF
          msg="Idle lock: never"
          detail="Re-enable with sleep-time <minutes>"
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

  # ── hyprlock lock screen (Catppuccin Mocha, matches walker-style.css) ──
  # hyprlang syntax verified against hyprlock 0.9.5 assets/example.conf.
  home.file.".config/hypr/hyprlock.conf".text = ''
    $font = JetBrainsMono Nerd Font

    general {
        hide_cursor = true
        disable_loading_bar = true
        grace = 5
        ignore_empty_input = true
    }

    # Blurred, dimmed wallpaper; solid Mocha base as fallback if the image is gone.
    background {
        monitor =
        path = ${homeDir}/Pictures/wallpapers_flat/wallpaper1.jpg
        color = rgba(1e1e2eff)
        blur_passes = 3
        blur_size = 6
        noise = 0.0117
        contrast = 0.9
        brightness = 0.75
        vibrancy = 0.17
        vibrancy_darkness = 0.0
    }

    # Clock
    label {
        monitor =
        text = $TIME
        font_size = 95
        font_family = $font
        color = rgba(cdd6f4ff)
        shadow_passes = 2
        shadow_size = 4
        halign = center
        valign = center
        position = 0, 130
    }

    # Date
    label {
        monitor =
        text = cmd[update:60000] date +"%A, %d %B"
        font_size = 26
        font_family = $font
        color = rgba(a6adc8ff)
        halign = center
        valign = center
        position = 0, 45
    }

    # Greeting
    label {
        monitor =
        text = Welcome back, hydragon2000
        font_size = 18
        font_family = $font
        color = rgba(a6adc8ff)
        halign = center
        valign = center
        position = 0, -55
    }

    # Password field — floating translucent pill
    input-field {
        monitor =
        size = 300, 55
        rounding = 16
        outline_thickness = 2
        inner_color = rgba(313244cc)
        outer_color = rgba(89b4faff)
        check_color = rgba(89b4faff)
        fail_color = rgba(f38ba8ff)
        font_color = rgba(cdd6f4ff)
        placeholder_text = <i>Password…</i>
        fail_text = <i>$FAIL (<b>$ATTEMPTS</b>)</i>
        fade_on_empty = true
        dots_spacing = 0.3
        halign = center
        valign = center
        position = 0, -130
    }
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

  home.packages = [ pkgs.hypridle pkgs.hyprlock ];
}
