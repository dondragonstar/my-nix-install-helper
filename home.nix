{ config, pkgs, ... }:

{
  home.username = "hydragon2000";
  home.homeDirectory = "/home/hydragon2000";
  home.stateVersion = "26.05";

  # Let Home Manager manage itself.
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    # Fill these in -- or leave unset and `git config --global` manually later.
    # userName = "hydragon2000";
    # userEmail = "you@example.com";
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      ll = "ls -la";
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#hydragon2000-pc";
    };
  };

  # Minimal placeholder Hyprland config so the compositor starts with
  # *something* on first login instead of a blank/black screen.
  # You will replace this with your own dotfiles once booted.
  home.file.".config/hypr/hyprland.conf".text = ''
    monitor=,preferred,auto,1

    exec-once = waybar

    input {
      kb_layout = us
      follow_mouse = 1
      natural_scroll = true
    }

    general {
      gaps_in = 4
      gaps_out = 8
      border_size = 2
    }

    decoration {
      rounding = 6
    }

    bind = SUPER, Return, exec, kitty
    bind = SUPER, Q, killactive,
    bind = SUPER, M, exit,
    bind = SUPER, E, exec, kitty -e nvim
    bind = SUPER, V, togglefloating,
    bind = SUPER, F, fullscreen,

    bind = SUPER, 1, workspace, 1
    bind = SUPER, 2, workspace, 2
    bind = SUPER, 3, workspace, 3
    bind = SUPER, 4, workspace, 4

    bind = SUPER SHIFT, 1, movetoworkspace, 1
    bind = SUPER SHIFT, 2, movetoworkspace, 2
    bind = SUPER SHIFT, 3, movetoworkspace, 3
    bind = SUPER SHIFT, 4, movetoworkspace, 4
  '';

  home.packages = with pkgs; [
    ripgrep
    fd
    btop
    neovim
  ];
}
