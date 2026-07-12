{ config, pkgs, username, hostname, gazelle, ... }:

let
  theme = import ./theme.nix;
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  # ── Environment variables ──
  home.sessionVariables = {
    NEWT_COLORS = ''
      root=default,default
      window=,default
      border=cyan,default
      textbox=default,default
      button=black,#89b4fa
      actbutton=black,#a6e3a1
      checkbox=default,default
      actcheckbox=black,#a6e3a1
      entry=default,default
      label=cyan,default
      listbox=white,default
      actlistbox=white,#89b4fa
    '';
  };

  # Let Home Manager manage itself.
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "dondragonstar";
        email = "dondragonstar@gmail.com";
      };

      # Automatically switch to professional config under ~/Projects/professional/
      includeIf."gitdir:~/Projects/professional/" = {
        path = "~/.gitconfig-professional";
      };
    };
  };

  # ── Professional git overrides ──
  home.file.".gitconfig-professional".text = ''
    [user]
      name = DevaJ2005
      email = devajb01@gmail.com

    # Rewrite GitHub URLs so the right SSH key is used
    [url "git@github-professional:"]
      insteadOf = git@github.com:
  '';

    # ── GTK theme (applies to Thunar, Rofi, and all GTK apps) ──
  gtk = {
    enable = true;

    theme = {
      name = "Catppuccin-Mocha-Standard-Blue-Dark";
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

  # ── Claude Desktop entry ──
  xdg.desktopEntries."claude-desktop" = {
    name = "Claude";
    comment = "Desktop application for Claude.ai";
    genericName = "AI Assistant";
    categories = [ "Utility" "Development" ];
    exec = "claude-desktop %u";
    icon = "claude-desktop";
    type = "Application";
    mimeType = [ "x-scheme-handler/claude" ];
    startupNotify = true;
    settings.StartupWMClass = "claude-desktop";
    settings.SingleMainWindow = "true";
    actions.NewChat = {
      name = "New chat";
      exec = "claude-desktop claude://claude.ai/new";
    };
    actions.NewCode = {
      name = "New Claude Code session";
      exec = "claude-desktop claude://code/new";
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  # ── SSH config: pick the right key per account ──
  programs.ssh = {
    enable = true;
    matchBlocks = {
      # Personal account (default)
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519_personal";
      };
      # Professional account — use a different host alias
      "github-professional" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519_professional";
      };
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    shellAliases = {
      ll = "ls -la";
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#${hostname}";
      drybuild = "sudo nixos-rebuild dry-build --flake /etc/nixos#${hostname}";
      cat = "bat";
      ls = "eza";
    };
    initContent = ''
      eval "$(starship init zsh)"
      eval "$(zoxide init zsh)"
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh
    '';
  };

  home.file.".config/waybar/config.jsonc".source = ./waybar-config.jsonc;
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

  # ── Alacritty ──
  home.file.".config/alacritty/alacritty.toml".source = ./alacritty.toml;

  # ── Gazelle (NetworkManager TUI) ──
  home.file.".config/gazelle/config.json".text = ''
    {
      "theme": "catppuccin-mocha"
    }
  '';

  # Minimal placeholder Hyprland config so the compositor starts with
  # *something* on first login instead of a blank/black screen.
  # You will replace this with your own dotfiles once booted.
  home.file.".config/hypr/hyprland.conf".text = ''
    monitor=,preferred,auto,1

    exec-once = waybar

    exec-once = awww-daemon
    exec-once = sleep 1 && awww img ~/Pictures/Wallpapers/wallpaper1.jpg

    # Cursor theme
    env = XCURSOR_THEME,Bibata-Modern-Classic
    env = XCURSOR_SIZE,24
    env = HYPRCURSOR_SIZE,24
    exec-once = hyprctl setcursor Bibata-Modern-Classic 24

    input {
      kb_layout = us
      follow_mouse = 1
      touchpad {
        natural_scroll = true
        scroll_factor = 1.0
      }
    }

    device {
      name = elan0518:00-04f3:31fc-touchpad
      scroll_factor = 1.0
    }

    general {
      gaps_in = 4
      gaps_out = 8
      border_size = 2
    }

    decoration {
      rounding = 6
    }

    bind = SUPER, Return, exec, alacritty
    bind = SUPER, W, killactive,
    bind = SUPER SHIFT, W, exec, alacritty --title 'Network Manager' -e gazelle
    bind = SUPER, M, exit,
    bind = SUPER, E, exec, zeditor
    bind = SUPER SHIFT, F, exec, thunar
    bind = SUPER, V, togglefloating,
    bind = SUPER, F, fullscreen,
    bind = SUPER, Space, exec, rofi -show drun
    bind = SUPER SHIFT, Space, exec, waypaper --backend swww
    bind = , Print, exec, screenshot region
    bind = SHIFT, Print, exec, screenshot screen

    bind = SUPER, 1, workspace, 1
    bind = SUPER, 2, workspace, 2
    bind = SUPER, 3, workspace, 3
    bind = SUPER, 4, workspace, 4
    bind = SUPER, 5, workspace, 5

    bind = SUPER SHIFT, 1, movetoworkspace, 1
    bind = SUPER SHIFT, 2, movetoworkspace, 2
    bind = SUPER SHIFT, 3, movetoworkspace, 3
    bind = SUPER SHIFT, 4, movetoworkspace, 4
    bind = SUPER SHIFT, 5, movetoworkspace, 5

    bindel = , XF86MonBrightnessUp, exec, brightnessctl set +5%
    bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

    bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
    bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

    bindm = SUPER, mouse:272, movewindow
    bindm = SUPER, mouse:273, resizewindow

    windowrule = match:class ^(org.pulseaudio.pavucontrol)$, float on, center on, size 900 600
    windowrule = match:class ^(rofi)$, float on, center on
    windowrule = match:class ^(claude-desktop)$, float on, center on, size 60% 80%
    windowrule = match:class ^(waypaper)$, float on, center on, size 60% 70%
    windowrule = match:title ^(Network Manager)$, float on, center on, size 900 550
    windowrule = dimaround, match:title ^(Network Manager)$
    windowrule = opacity 0.95 0.90, match:title ^(Network Manager)$
  '';

  # ── Claude Desktop wrapper ──
  home.packages = with pkgs; [
    (pkgs.writeShellScriptBin "claude-desktop" ''
      exec ${pkgs.appimage-run}/bin/appimage-run /home/${username}/Claude_Desktop-1.18286.0-x86_64.AppImage "$@"
    '')
    ripgrep
    fd
    btop
    neovim
    rofi
    zed-editor
    alacritty
    antigravity
    starship
    zoxide
    fzf
    bat
    eza
    brightnessctl
    playerctl
    nautilus
    thunar
    gvfs
    pavucontrol
    networkmanagerapplet
    # networkmanager_dmenu
    gazelle.packages.${pkgs.system}.default
    awww
    waypaper
    (pkgs.writeShellScriptBin "swww" "exec ${pkgs.awww}/bin/awww \"$@\"")
    (pkgs.writeShellScriptBin "swww-daemon" "exec ${pkgs.awww}/bin/awww-daemon \"$@\"")
    (pkgs.writeShellScriptBin "screenshot" ''
      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"
      app=$(hyprctl activewindow | grep '^class: ' | sed 's/^class: //' | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_' | sed 's/_*$//')
      [ -z "$app" ] && app="unknown"
      ts=$(date +%H_%M_%d_%m_%y)
      case "''${1:-screen}" in
        region) grim -g "$(slurp)" "$dir/''${app}_''${ts}.png" ;;
        screen) grim "$dir/''${app}_''${ts}.png" ;;
      esac
    '')
    grim
    slurp
    wl-clipboard
    wget
    opencode
    gcc
    gnumake
    binutils
    nasm
    bochs
    grub2
    xorriso
    seabios
    rustc
    cargo
    rustfmt
    clippy
    rust-analyzer
    python3
    telegram-desktop
    vlc
    qimgv
    zathura
    papirus-icon-theme
    catppuccin-gtk
    lxappearance
    ffmpegthumbnailer
    poppler
    glib
    discord
  ];
}
