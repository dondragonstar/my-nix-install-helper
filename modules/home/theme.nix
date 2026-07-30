{ config, pkgs, lib, ... }:

{
  # ── GTK theme (applies to Thunar, Rofi, and all GTK apps) ──
  gtk = {
    enable = true;

    theme = {
      name = "catppuccin-mocha-blue-standard+rimless";
      package = pkgs.catppuccin-gtk.override {
        accents = [ "blue" ];
        size = "standard";
        tweaks = [ "rimless" ];
        variant = "mocha";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # ── Cursor theme (applies to all applications) ──
  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    hyprcursor.enable = true;
  };

  # ── XDG / Desktop entries ──
  xdg.enable = true;

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  # ── AI agent protocol distribution ──
  # /etc/nixos/AGENTS.md is the single source; these symlinks make every
  # agent tool find it. mkOutOfStoreSymlink → edits apply without rebuild.
  home.file."AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/AGENTS.md";
  home.file."GEMINI.md".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/AGENTS.md";
}
