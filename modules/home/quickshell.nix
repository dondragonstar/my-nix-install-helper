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
  # Started via hyprland exec-once so it survives nixos-rebuild without a
  # reboot. The systemd service wrapper gives us restart-on-failure.
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell status bar";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "no";
      SuccessExitStatus = [ 0 255 ];
    };
  };
}
