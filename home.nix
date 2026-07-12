{ config, pkgs, username, hostname, wlctl, ... }:

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

  # ── wlctl (NetworkManager TUI) config ──
  home.file.".config/impala/config.toml".text = ''
    [keybindings]
    quit = "escape"
    toggle_power = "o"
    scan = "s"
    connect = "space"
    disconnect = "d"
    toggle_connect = "space"
    up = "up"
    down = "down"
    toggle_enable = "o"
    start = "n"
    stop = "x"
    restart = "r"
    toggle_autoconnect = "a"
    back = "backspace"
  '';

  # ── Hyprland Lua config (HM-native, 26.05+ style) ──
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    extraConfig = ''
      -- Monitor
      hl.monitor({
          output   = "",
          mode     = "preferred",
          position = "auto",
          scale    = "auto",
      })

      -- Startup
      hl.on("hyprland.start", function()
          hl.exec_cmd("waybar")
          hl.exec_cmd("awww-daemon")
          hl.exec_cmd("sleep 1 && awww img ~/Pictures/Wallpapers/wallpaper1.jpg")
      end)

      -- Environment
      hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
      hl.env("XCURSOR_SIZE", "24")
      hl.env("HYPRCURSOR_SIZE", "24")

      -- Input, general, decoration
      hl.config({
          input = {
              kb_layout    = "us",
              follow_mouse = 1,
              touchpad = {
                  natural_scroll = true,
                  scroll_factor  = 1.0,
              },
          },
          general = {
              gaps_in    = 4,
              gaps_out   = 8,
              border_size = 2,
          },
          decoration = {
              rounding = 6,
          },
      })

      -- Device-specific
      hl.device({
          name          = "elan0518:00-04f3:31fc-touchpad",
          scroll_factor = 1.0,
      })

      -- Keybinds
      hl.bind("SUPER + Return",         hl.dsp.exec_cmd("alacritty"))
      hl.bind("SUPER + W",              hl.dsp.window.close())
      hl.bind("SUPER SHIFT + W",        hl.dsp.exec_cmd("alacritty --title wlctl -e wlctl"))
      hl.bind("SUPER + M",              hl.dsp.exec_cmd("hyprctl dispatch exit"))
      hl.bind("SUPER + E",              hl.dsp.exec_cmd("zeditor"))
      hl.bind("SUPER SHIFT + F",        hl.dsp.exec_cmd("thunar"))
      hl.bind("SUPER + V",              hl.dsp.window.float({ action = "toggle" }))
      hl.bind("SUPER + F",              hl.dsp.exec_cmd("hyprctl dispatch fullscreen"))
      hl.bind("SUPER + Space",          hl.dsp.exec_cmd("rofi -show drun"))
      hl.bind("SUPER SHIFT + Space",    hl.dsp.exec_cmd("waypaper --backend swww"))
      hl.bind("Print",                  hl.dsp.exec_cmd("screenshot region"))
      hl.bind("SHIFT + Print",          hl.dsp.exec_cmd("screenshot screen"))

      hl.bind("SUPER + 1",              hl.dsp.focus({ workspace = 1 }))
      hl.bind("SUPER + 2",              hl.dsp.focus({ workspace = 2 }))
      hl.bind("SUPER + 3",              hl.dsp.focus({ workspace = 3 }))
      hl.bind("SUPER + 4",              hl.dsp.focus({ workspace = 4 }))
      hl.bind("SUPER + 5",              hl.dsp.focus({ workspace = 5 }))

      hl.bind("SUPER SHIFT + 1",        hl.dsp.window.move({ workspace = 1 }))
      hl.bind("SUPER SHIFT + 2",        hl.dsp.window.move({ workspace = 2 }))
      hl.bind("SUPER SHIFT + 3",        hl.dsp.window.move({ workspace = 3 }))
      hl.bind("SUPER SHIFT + 4",        hl.dsp.window.move({ workspace = 4 }))
      hl.bind("SUPER SHIFT + 5",        hl.dsp.window.move({ workspace = 5 }))

      -- Hardware keys
      hl.bind("XF86MonBrightnessUp",    hl.dsp.exec_cmd("brightnessctl set +5%"),   { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown",  hl.dsp.exec_cmd("brightnessctl set 5%-"),   { locked = true, repeating = true })
      hl.bind("XF86AudioRaiseVolume",   hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume",   hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute",          hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })

      -- Mouse binds
      hl.bind("SUPER + mouse:272",      hl.dsp.window.drag(),   { mouse = true })
      hl.bind("SUPER + mouse:273",      hl.dsp.window.resize(), { mouse = true })

      -- Window rules for other apps
      hl.window_rule({
          name   = "pavucontrol",
          match  = { class = "org.pulseaudio.pavucontrol" },
          float  = true,
          center = true,
          size   = "900 600",
      })
      hl.window_rule({
          name   = "rofi",
          match  = { class = "rofi" },
          float  = true,
          center = true,
      })
      hl.window_rule({
          name   = "claude-desktop",
          match  = { class = "claude-desktop" },
          float  = true,
          center = true,
          size   = "60% 80%",
      })
      hl.window_rule({
          name   = "waypaper",
          match  = { class = "waypaper" },
          float  = true,
          center = true,
          size   = "60% 70%",
      })
    '';
    extraLuaFiles = {
      "wlctl-rule" = {
        content = ''
          hl.window_rule({
              name   = "wlctl",
              match  = { title = "wlctl" },
              float  = true,
              center = true,
              size   = "900 550",
          })
        '';
        autoLoad = true;
      };
    };
  };

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
    wlctl.packages.${pkgs.system}.default
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
