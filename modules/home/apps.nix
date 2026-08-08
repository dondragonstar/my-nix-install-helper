{ config, pkgs, lib, username, wlctl, zen-browser, zen-browser-unwrapped, ... }:

{
  # ── Vesktop: screen-share flags are baked into the `vesktop` binary wrapper
  #    below, so this entry can stay clean (flags apply from any launcher) ──
  xdg.desktopEntries."vesktop" = {
    name = "Vesktop";
    exec = "vesktop %U";
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

  # ── Nixup desktop entry ──
  xdg.desktopEntries."nixup" = {
    name = "Nixup";
    comment = "Selective flake input updater";
    exec = "nixup";
    icon = "software-update-urgent";
    type = "Application";
    categories = [ "System" "Utility" ];
    settings.StartupWMClass = "nixup";
  };

  # ── Zen Browser ──
  # Standard daily-driver (vertical tabs, workspaces, split view) rebuilt from
  # the official binary tarball. Re-wrapped to inject the Widevine CDM path:
  # Zen has no Google Widevine license, but Linux VMP is NOT enforced, so the
  # CDM shipped in pkgs.widevine-cdm (home.file ~/.widevine-cdm below) plays
  # Netflix/Prime/Spotify web fine. NO Google approved signature needed.
  home.packages = with pkgs; [
    # ── Claude Desktop wrapper ──
    # Clean up stale IPC socket from previous runs (Electron apps leave this behind
    # when quit from tray, which blocks the next launch)
    (pkgs.writeShellScriptBin "claude-desktop" ''
      rm -f "/run/user/$(id -u)/claude-desktop-qe.sock"
      exec ${pkgs.appimage-run}/bin/appimage-run /home/${username}/Claude_Desktop-1.18286.0-x86_64.AppImage "$@"
    '')
    (pkgs.wrapFirefox zen-browser-unwrapped {
      pname = "zen-browser";
      extraPolicies = {
        DisableAppUpdate = true;
        DisableTelemetry = true;
      };
      extraPrefs = ''
        lockPref("media.gmp-widevinecdm.enabled", true);
        lockPref("media.gmp-widevinecdm.path", "/home/${config.home.username}/.widevine-cdm");
'';
    })
    walker
    uwsm
    elephant
    ripgrep
    fd
    # Brave must run native Wayland (ozone) or its share picker only lists
    # X11 windows — full-screen share impossible.
    (pkgs.brave.override {
      commandLineArgs = [
        "--ozone-platform=wayland"
        "--enable-features=WebRTCPipeWireCapturer"
      ];
    })
    btop
    qdirstat
    zed-editor
    alacritty
    (pkgs.writeShellScriptBin "antigravity" ''
      unset NIXOS_OZONE_WL
      exec ${pkgs.antigravity}/bin/antigravity --no-sandbox "$@"
    '')
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
    rclone
    fuse3
    awww
    waypaper
    onlyoffice-desktopeditors
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
    nix-output-monitor
    telegram-desktop
    cheese
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
    # ── Vesktop wrapper: always inject the Wayland screen-share flags so
    #    streaming works from ANY launch path (walker, keybind, terminal),
    #    not just this desktop entry. Ships the package icons too.
    #    --disable-gpu-compositing avoids the intermittent black window on
    #    NVIDIA+Wayland (SCANOUT GBM buffer allocation failure).
    (pkgs.runCommand "vesktop" { }
      ''
        mkdir -p $out/bin $out/share
        cp -rs ${pkgs.vesktop}/share/icons $out/share/icons
        cat > $out/bin/vesktop <<'WRAP'
        #!/bin/sh
        exec ${pkgs.vesktop}/bin/vesktop --ozone-platform-hint=auto --enable-features=WebRTCPipeWireCapturer --disable-gpu-sandbox --disable-gpu-compositing "$@"
        WRAP
        chmod +x $out/bin/vesktop
      '')
    jq
    libnotify
    (pkgs.writeShellScriptBin "nixup" ''
      exec ${pkgs.python3}/bin/python3 /etc/nixos/bin/nixup "$@"
    '')
    # ── Streaming / daily-drive essentials ──
    obs-studio
    ffmpeg-full
    noisetorch
    exfatprogs
    ntfs3g
  ];

  # ── Widevine CDM floor for Zen + Firefox (Netflix/Prime/Spotify web) ──
  # Flat layout required: Gecko wants libwidevinecdm.so directly in the dir
  # pointed at by media.gmp-widevinecdm.path (set in the wrappers above/below).
  home.file.".widevine-cdm/libwidevinecdm.so".source =
    "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm/_platform_specific/linux_x64/libwidevinecdm.so";

  # ── Default browser: Zen ──
  xdg.mimeApps.defaultApplications = {
    "text/html" = "zen-browser.desktop";
    "text/xml" = "zen-browser.desktop";
    "application/xhtml+xml" = "zen-browser.desktop";
    "x-scheme-handler/http" = "zen-browser.desktop";
    "x-scheme-handler/https" = "zen-browser.desktop";
  };
}
