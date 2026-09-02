{ config, pkgs, lib, username, wlctl, zen-browser, zen-browser-unwrapped, walker, ... }:

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

  # ── Brave: override desktop entry so walker/elephant launch our wrapper
  #    (which bakes env + flags) instead of the upstream nix store binary ──
  xdg.desktopEntries."brave-browser" = {
    name = "Brave Web Browser";
    exec = "brave %U";
    icon = "brave-browser";
    type = "Application";
    categories = [ "Network" "WebBrowser" ];
    mimeType = [ "text/html" "x-scheme-handler/http" "x-scheme-handler/https" ];
    settings.StartupWMClass = "brave-browser";
  };

  # ── Zen: override desktop entry to force MOZ_ENABLE_WAYLAND=1 so Zen
  #    uses native Wayland (PipeWire screenshare works). The session-level
  #    MOZ_ENABLE_WAYLAND=0 is for Firefox's popup bug — Zen is unaffected. ──
  xdg.desktopEntries."zen" = {
    name = "Zen Browser";
    exec = "env MOZ_ENABLE_WAYLAND=1 zen --name zen %U";
    icon = "zen";
    type = "Application";
    categories = [ "Network" "WebBrowser" ];
    mimeType = [ "text/html" "x-scheme-handler/http" "x-scheme-handler/https" ];
    settings.StartupWMClass = "zen";
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

  home.packages = with pkgs; [
    # ── Claude Desktop wrapper ──
    # Clean up stale IPC socket from previous runs (Electron apps leave this behind
    # when quit from tray, which blocks the next launch)
    (pkgs.writeShellScriptBin "claude-desktop" ''
      rm -f "/run/user/$(id -u)/claude-desktop-qe.sock"
      exec ${pkgs.appimage-run}/bin/appimage-run /home/${username}/Applications/Claude_Desktop-1.18286.0-x86_64.AppImage "$@"
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
# walker comes from the walker-git flake input (2.17.0) — see flake.nix;
    # 26.05's 2.16.2 daemon core-dumps at login (activate/connect_changed panic)
    walker
    uwsm
    elephant
    ripgrep
    fd
    # Brave: runCommand wrapper (like vesktop) bakes env + flags into the
    # script so screenshare works from ANY launch path (walker, keybind,
    # terminal). pkgs.brave.override only adds CLI flags — env vars set in
    # home.sessionVariables are missing from walker/elephant systemd scopes.
    (pkgs.runCommand "brave" { }
      ''
        mkdir -p $out/bin $out/share
        cp -rs ${pkgs.brave}/share/* $out/share/ 2>/dev/null || true
        cat > $out/bin/brave <<'WRAP'
        #!/bin/sh
        export XDG_SESSION_TYPE=wayland
        export NIXOS_OZONE_WL=1
        export ELECTRON_OZONE_PLATFORM_HINT=auto
        exec ${pkgs.brave}/bin/brave --ozone-platform-hint=auto --enable-features=WebRTCPipeWireCapturer --disable-gpu-compositing "$@"
        WRAP
        chmod +x $out/bin/brave
      '')
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
        export XDG_SESSION_TYPE=wayland
        export NIXOS_OZONE_WL=1
        export ELECTRON_OZONE_PLATFORM_HINT=auto
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
    "text/html" = "zen.desktop";
    "text/xml" = "zen.desktop";
    "application/xhtml+xml" = "zen.desktop";
    "x-scheme-handler/http" = "zen.desktop";
    "x-scheme-handler/https" = "zen.desktop";
    "x-scheme-handler/about" = "zen.desktop";
    "x-scheme-handler/unknown" = "zen.desktop";
    "application/pdf" = "zen.desktop";
  };
}
