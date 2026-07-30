{ config, pkgs, lib, ... }:

{
  home.file.".config/quickshell" = {
    source = ../../quickshell;
    recursive = true;
  };

  home.packages = with pkgs; [
    quickshell
    hyprlock
    brightnessctl
  ];

  # ── Quickshell systemd user service ──
  # Mirrors the waybar service pattern: survives nixos-rebuild without a
  # reboot, and only autostarts when quickshell is the chosen bar.
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell status bar";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install = lib.mkIf (config.my.barChoice == "quickshell") {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
