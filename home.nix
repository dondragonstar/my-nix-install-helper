{ config, pkgs, lib, username, hostname, wlctl, ... }:

{
  # ── Home-manager config, split by concern into modules/home/ ──
  # Machine-specific values (username, hostname, wlctl) arrive via
  # extraSpecialArgs in flake.nix and are available to every module below.
  imports = [
    ./modules/home/hyprland.nix
    ./modules/home/walker.nix
    ./modules/home/waybar.nix
    ./modules/home/quickshell.nix
    ./modules/home/theme.nix
    ./modules/home/git.nix
    ./modules/home/zsh.nix
    ./modules/home/apps.nix
    ./modules/home/nvim.nix
    ./modules/home/drive.nix
    ./modules/home/idle.nix
    ./modules/home/lockshell.nix
    ./modules/home/spotify.nix
    ./modules/home/branding.nix
  ];

  options.my.barChoice = lib.mkOption {
    type = lib.types.enum [ "waybar" "quickshell" ];
    default = "quickshell";
    description = "Which status bar autostarts.";
  };

  config = {
    home.username = username;
    home.homeDirectory = "/home/${username}";
    home.stateVersion = "26.05";

    home.sessionVariables = {
      QT_QPA_PLATFORMTHEME = "gtk3";
      NIXOS_OZONE_WL = "1";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      # Firefox 153 native-Wayland popups (hamburger menu, search suggestions,
      # toolbar menus) collapse to 10px slivers with no text — Firefox GTK
      # layout bug, compositor/profile-independent (repro'd on fresh profile,
      # XWayland renders correctly). Force XWayland until upstream fixes it.
      MOZ_ENABLE_WAYLAND = "0";
      XDG_SCREENSHOTS_DIR = "$HOME/Pictures/Screenshots";
    };

    home.sessionPath = [ "$HOME/.local/bin" ];

    programs.npm = {
      enable = true;
      settings = {
        prefix = "~/.local/bin";
      };
    };

    programs.home-manager.enable = true;
  };
}
