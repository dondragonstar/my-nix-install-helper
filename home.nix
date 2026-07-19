{ config, pkgs, lib, username, hostname, wlctl, ... }:

let
  theme = import ./theme.nix;
  keybinds = import ./keybinds.nix;

  # Generate a Hyprland bind line from a keybind entry
  mkBindLine = b:
    let type = b.type or "bind"; in
    "${type} = ${b.mods}, ${b.key}, ${b.action}";

  # Human-readable key combo for the menu display
  displayKeys = b:
    let mods = b.mods or ""; in
    if mods == "" then b.key
    else "${lib.replaceStrings [" "] [" + "] mods} + ${b.key}";

  # All hyprland bind lines joined
  hyprlandBinds = lib.concatStringsSep "\n" (map mkBindLine keybinds.binds);

  # Escape a string for use in Lua string literals
  escapeLua = lib.replaceStrings ["\\" "\""] ["\\\\" "\\\""];

  # Generate Lua table entries for the Elephant keybinds menu
  keybindsLuaEntries = lib.concatStringsSep ",\n" (map (b: ''
        {
          Text = "${escapeLua b.description}",
          Subtext = "${escapeLua (displayKeys b)}  (${b.category})",
          Value = "${escapeLua (displayKeys b)}",
        }'') keybinds.binds);
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  # ── Environment variables ──
  home.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "gtk3";
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    # Force pipewire screen sharing for Electron apps
    XDG_SCREENSHOTS_DIR = "$HOME/Pictures/Screenshots";
  };

  # ── User binary PATH (RTK and other manually installed tools) ──
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Let Home Manager manage itself.
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;

    settings = {
      # No global user — handled by per-directory includes below.
      # Order matters: git processes config top-to-bottom.
      # gitdir:~  matches everything under $HOME; gitdir:~/Projects/professional/ is more specific.
      # For professional repos, both match — personal loads first, professional overrides second.

      includeIf."gitdir:~/Projects/professional/" = {
        path = "~/.gitconfig-professional";
      };

      includeIf."gitdir:~/" = {
        path = "~/.gitconfig-personal";
      };
    };
  };

  # ── Personal git identity (applies to all repos except professional) ──
  home.file.".gitconfig-personal".text = ''
    [user]
      name = dondragonstar
      email = dondragonstar@gmail.com
  '';

  # ── Professional git identity and URL rewrite ──
  home.file.".gitconfig-professional".text = ''
    [user]
      name = DevaJ2005
      email = devajb01@gmail.com

    [url "git@github-professional:"]
      insteadOf = git@github.com:
  '';

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

  # ── Vesktop: forced flags for screen sharing ──
  xdg.desktopEntries."vesktop" = {
    name = "Vesktop";
    exec = "vesktop --ozone-platform-hint=auto --enable-features=WebRTCPipeWireCapturer --disable-gpu-sandbox %U";
    icon = "vesktop";
    type = "Application";
    categories = [ "Network" "InstantMessaging" "Chat" ];
    mimeType = [ "x-scheme-handler/discord" ];
    settings.StartupWMClass = "Vesktop";
  };

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

  # ── Walker (app launcher) + Elephant (desktop indexer) ──
  # Manual setup (no HM module — clean slate per Omarchy reference).

  # Walker config (generated from Nix)
  xdg.configFile."walker/config.toml".text = ''
    force_keyboard_focus = true
    selection_wrap = true
    theme = "omarchy-default"
    additional_theme_location = "~/.local/share/omarchy/default/walker/themes/"
    hide_action_hints = true

    [placeholders]
    "default" = { input = " Search...", list = "No Results" }

    [builtins.applications]
    launch_prefix = "uwsm app -- "
    history = true

    [columns]
    symbols = 1

    [providers]
    max_results = 256
    default = [ "desktopapplications", "websearch", "menus" ]

    # Dedicated keybinds-only provider set for SUPER+H
    [providers.sets.keybinds]
    default = ["menus"]
    empty = ["menus"]

    [[providers.prefixes]]
    prefix = "/"
    provider = "providerlist"

    [[providers.prefixes]]
    prefix = "."
    provider = "files"

    [[providers.prefixes]]
    prefix = ":"
    provider = "symbols"

    [[providers.prefixes]]
    prefix = "="
    provider = "calc"

    [[providers.prefixes]]
    prefix = "@"
    provider = "websearch"

    [[providers.prefixes]]
    prefix = "$"
    provider = "clipboard"

    # Type ? to search keybinds exclusively
    [[providers.prefixes]]
    prefix = "?"
    provider = "menus:keybinds"

    [[emergencies]]
    text = "Restart Walker"
    command = "pkill walker || true; uwsm app -- walker --gapplication-service &"
  '';

  # Theme files at the Omarchy location
  home.file.".local/share/omarchy/default/walker/themes/omarchy-default/style.css".source = ./walker-style.css;
  home.file.".local/share/omarchy/default/walker/themes/omarchy-default/layout.xml".source = ./walker-layout.xml;

  # ── AI agent protocol distribution ──
  # /etc/nixos/AGENTS.md is the single source; these symlinks make every
  # agent tool find it. mkOutOfStoreSymlink → edits apply without rebuild.
  home.file."AGENTS.md".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/AGENTS.md";
  home.file."GEMINI.md".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/AGENTS.md";

  # Elephant config: use uwsm as launch prefix so apps get proper session activation
  xdg.configFile."elephant/elephant.toml".text = ''
    launch_prefix = "uwsm app --"
  '';

  # Elephant systemd service — ensure it starts with the graphical session
  systemd.user.services.elephant = {
    Unit = {
      Description = "Elephant launcher backend";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.elephant}/bin/elephant";
      Restart = "always";
      RestartSec = 2;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # ── SSH config: pick the right key per account ──
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519_personal";
      };
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
      update = "nix flake update /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos#${hostname}";
      gcsize = "nix-store --gc --print-dead | tr '\\n' '\\0' | xargs -0 du -hc | tail -n 1";
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

  # ── Hyprland config (hyprlang — nixpkgs Hyprland is built without Lua) ──
  home.file.".config/hypr/hyprland.conf".text = ''
    monitor=,preferred,auto,1

    exec-once = waybar
    exec-once = awww-daemon
    exec-once = sleep 1 && awww img ~/Pictures/Wallpapers/wallpaper1.jpg
    exec-once = hyprctl setcursor Bibata-Modern-Classic 24

    # Import Wayland display into systemd user manager so services inherit it
    exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

    # Walker daemon (delayed for elephant + Wayland readiness)
    # We use a small helper that ensures elephant is running before launching walker
    exec-once = uwsm app -- sh -c 'systemctl --user start elephant && walker --gapplication-service'
    exec-once = systemctl --user start tumblerd

    env = XCURSOR_THEME,Bibata-Modern-Classic
    env = XCURSOR_SIZE,24
    env = HYPRCURSOR_SIZE,24

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

    # ── Keybinds (generated from keybinds.nix) ──
  '' + "\n" + hyprlandBinds + "\n" + ''
    # ── Window rules ──
    windowrule = match:class ^(org.pulseaudio.pavucontrol)$, float on, center on, size 900 600
    windowrule = match:class ^(claude-desktop)$, float on, center on, size 60% 80%
    windowrule = match:class ^(waypaper)$, float on, center on, size 60% 70%
    windowrule = match:title ^(wlctl)$, float on, center on, size 900 550
    windowrule = match:title ^(bluetuith)$, float on, center on, size 900 550
  '';

  # ── Keybind menu (Elephant Lua — integrated into Walker search) ──
  home.file.".config/elephant/menus/keybinds.lua".text = ''
    Name = "keybinds"
    NamePretty = "Keybinds"
    Icon = "preferences-desktop-keyboard-shortcuts"
    Cache = false
    Action = "sh -c 'echo -n %VALUE% | wl-copy && notify-send \"Keybinds\" \"Copied shortcut to clipboard\"'"

    function GetEntries()
      return {
        ${keybindsLuaEntries}
      }
    end
  '';

  home.activation.removeStaleHyprlandLua = config.lib.dag.entryAfter ["writeBoundary"] ''
    rm -f $HOME/.config/hypr/hyprland.lua
  '';

  # ── Claude Desktop wrapper ──
  home.packages = with pkgs; [
    (pkgs.writeShellScriptBin "claude-desktop" ''
      # Clean up stale IPC socket from previous runs (Electron apps leave this behind
      # when quit from tray, which blocks the next launch)
      rm -f "/run/user/$(id -u)/claude-desktop-qe.sock"
      exec ${pkgs.appimage-run}/bin/appimage-run /home/${username}/Claude_Desktop-1.18286.0-x86_64.AppImage "$@"
    '')
    walker
    uwsm
    elephant
    ripgrep
    fd
    btop
    qdirstat
    zed-editor
    alacritty
    antigravity
    claude-code
    starship
    zoxide
    fzf
    bat
    eza
    brightnessctl
    playerctl
    thunar
    tumbler
    gvfs
    pavucontrol
    (pkgs.writeShellScriptBin "bluetuith-launcher" ''
      exec alacritty --title bluetuith -e bluetuith "$@"
    '')
    blueman
    bluetuith
    wlctl.packages.${pkgs.stdenv.hostPlatform.system}.default
    awww
    waypaper
    (pkgs.writeShellScriptBin "swww" "exec ${pkgs.awww}/bin/awww \"$@\"")
    (pkgs.writeShellScriptBin "swww-daemon" "exec ${pkgs.awww}/bin/awww-daemon \"$@\"")
    (pkgs.writeShellScriptBin "screenshot" ''
      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"
      app=$(hyprctl activewindow | grep -oP '^[[:blank:]]*title: \K.*' | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_' | sed 's/_*$//')
      [ -z "$app" ] && app=$(hyprctl activewindow | grep -oP '^[[:blank:]]*class: \K.*' | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_' | sed 's/_*$//')
      [ -z "$app" ] && app="unknown"
      ts=$(date +%H_%M_%d_%m_%y)
      case "''${1:-screen}" in
        region) grim -g "$(slurp)" "$dir/''${app}_''${ts}.png" ;;
        screen) grim "$dir/''${app}_''${ts}.png" ;;
      esac
    '')
    (pkgs.writeShellScriptBin "wlctl-launcher" ''
      exec alacritty --title wlctl -e wlctl "$@"
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
    nodejs
    pnpm
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
    vesktop
    jq
    libnotify
  ];
}
