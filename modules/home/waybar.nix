{ config, pkgs, lib, ... }:

let
  theme = import ../../theme.nix;
in
{
  home.file.".config/waybar/config.jsonc".source = ../../waybar-config.jsonc;
  home.file.".config/waybar/style.css".text = ''
    * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        min-height: 0;
    }

    window#waybar {
        background: ${theme.current.waybar.background};
        color: ${theme.current.waybar.text};
    }

    #workspaces,
    #window,
    #clock,
    #network,
    #cpu,
    #temperature,
    #memory,
    #backlight,
    #pulseaudio,
    #battery,
    #tray {
        margin: 4px;
        padding: 0 10px;
        border-radius: 10px;
        background: ${theme.current.waybar.item-background};
    }

    #workspaces button {
        padding: 0 8px;
        border-radius: 8px;
        color: ${theme.current.waybar.item-text};
    }

    #workspaces button.active {
        color: ${theme.current.waybar.active-item-text};
        background: ${theme.current.waybar.active-item-background};
    }

    #battery.warning {
        color: ${theme.current.waybar.warning};
    }

    #battery.critical {
        color: ${theme.current.waybar.critical};
    }
  '';

  # ── Waybar systemd user service ──
  # Replaces `exec-once = waybar` in hyprland.conf. Survives nixos-rebuild
  # without a reboot (rebuild restarts the graphical session's services;
  # exec-once only fires at Hyprland launch). Same pattern as elephant.
  systemd.user.services.waybar = {
    Unit = {
      Description = "Waybar status bar";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.waybar}/bin/waybar";
      Restart = "on-failure";
      RestartSec = 2;
    };
    # Only autostart waybar when it's the chosen bar. When quickshell is
    # chosen, this service still exists (so `systemctl --user start waybar`
    # works for manual testing) but won't be pulled in by the graphical
    # session target.
    Install = lib.mkIf (config.my.barChoice == "waybar") {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
