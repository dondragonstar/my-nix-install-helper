{ config, lib, pkgs, hostname, username, machine, hyprland, xdph, ... }:

{
  # hardware-configuration.nix is imported via flake.nix's modules list,
  # not here -- this avoids the duplicate-import trap some tutorials cause
  # when both flake.nix and configuration.nix reference it.

  ##############################################################
  ## Boot / Bootloader
  ##############################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 3;

  ##############################################################
  ## Networking
  ##############################################################
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  ##############################################################
  ## Time / Locale
  ##############################################################
  time.timeZone = machine.timezone;
  i18n.defaultLocale = "en_US.UTF-8";

  ##############################################################
  ## Nix settings
  ##############################################################
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [
      "https://walker.cachix.org"
      "https://walker-git.cachix.org"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # Garbage collection is handled by nh clean (runs after every `nh os switch`,
  # --keep-since 4d --keep 3) — the nix.gc timer was dropped to avoid the
  # programs.nh.clean / nix.gc.automatic conflict the nh module warns about.
  # Store dedup still runs on a weekly timer.
  nix.optimise.automatic = true;

  # [nh-migration] programs.nh
  programs.nh = {
    enable = true;
    flake = "/etc/nixos";
    clean = {
      enable = true;
      extraArgs = "--keep-since 4d --keep 3";
    };
  };

  nixpkgs.config.allowUnfree = true;

  ##############################################################
  ## Graphics (vendor-specific config lives in modules/hardware/,
  ## selected by the gpu field in machine.nix)
  ##############################################################
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # CPU microcode per machine.nix (nixos-generate-config also sets a
  # default; this makes the choice explicit and portable)
  hardware.cpu.intel.updateMicrocode = lib.mkIf (machine.cpu == "intel") true;
  hardware.cpu.amd.updateMicrocode = lib.mkIf (machine.cpu == "amd") true;

  ##############################################################
  ## Hyprland (via nixpkgs module)
  ##############################################################
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    # Use pinned v0.56.1 (see flake.nix) instead of nixpkgs 26.05's 0.55.4,
    # which has the popup-subsurface scaling bug (hyprwm/Hyprland#14936) that
    # makes Firefox menus render as slivers.
    package = hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    # Pinned portal (see flake.nix xdph input): the one bundled with the
    # hyprland input predates the event-loop hangup fix (#417) and spins at
    # ~100% CPU after a screenshot/screencast (hyprwm/xdg-desktop-portal-hyprland#411).
    portalPackage = xdph.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  ##############################################################
  ## Login greeter (greetd + ReGreet)
  ##
  ## ReGreet discovers sessions from the displayManager session
  ## integration (greetd enables it automatically), so the Hyprland
  ## session desktop file (Exec=start-hyprland) shows up in the
  ## login screen dropdown. Background rotates each boot via the
  ## regreet-wallpaper systemd unit below.
  ##############################################################
  programs.regreet = {
    enable = true;

    # Matches the desktop theme: Catppuccin Mocha (blue accent, rimless),
    # Papirus-Dark icons, Bibata-Modern-Classic cursor, JetBrainsMono Nerd Font.
    theme = {
      package = pkgs.catppuccin-gtk.override {
        variant = "mocha";
        accents = [ "blue" ];
        size = "standard";
        tweaks = [ "rimless" ];
      };
      name = "catppuccin-mocha-blue-standard+rimless";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
    };
    font = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
      size = 16;
    };

    settings = {
      background = {
        path = "/var/lib/regreet/background.png";
        fit = "Cover";
      };
      appearance.greeting_msg = "Welcome back";
      GTK.application_prefer_dark_theme = true;
      commands = {
        reboot = [ "systemctl" "reboot" ];
        poweroff = [ "systemctl" "poweroff" ];
      };
    };
  };

  # greetd launches the greeter (cage) as this user; it needs access to DRM,
  # input and render devices to display ReGreet and handle keyboard/mouse.
  users.users.greeter = {
    isSystemUser = true;
    group = "greeter";
    extraGroups = [ "video" "render" "input" "seat" "tty" ];
  };

  # Rotate the login-screen wallpaper each boot: pick a random image from the
  # user's wallpaper folder and copy it to the greeter-accessible location
  # (/var/lib/regreet/background.png, created+owned by greeter via tmpfiles).
  systemd.services.regreet-wallpaper = {
    description = "Pick a random wallpaper for the ReGreet login screen";
    wantedBy = [ "multi-user.target" ];
    before = [ "greetd.service" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    path = [ pkgs.coreutils pkgs.findutils ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "regreet-wallpaper" ''
        set -euo pipefail
        dest=/var/lib/regreet/background.png
        dir=${config.users.users.${username}.home}/Pictures/wallpapers_flat
        if [ ! -d "$dir" ]; then
          exit 0
        fi
        # Real wallpapers are >100KB; the folder also contains tiny cursor/UI
        # assets (waypaper) that must be skipped.
        mapfile -t candidates < <(
          find "$dir" -maxdepth 1 -type f \
            \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
            -size +100k -print 2>/dev/null
        )
        if [ ''${#candidates[@]} -eq 0 ]; then
          exit 0
        fi
        pick=''${candidates[$((RANDOM % ''${#candidates[@]}))]}
        install -o greeter -g greeter -m 0644 "$pick" "$dest"
        # Seed ReGreet's session cache so Hyprland is pre-selected in the
        # login dropdown (avoids the default-login-shell fallback).
        state=/var/lib/regreet/state.toml
        if [ ! -f "$state" ] || ! grep -q "^${username} = " "$state"; then
          printf 'last_user = "%s"\n\n[user_to_last_sess]\n%s = "Hyprland"\n' \
            "${username}" "${username}" > "$state"
          chown greeter:greeter "$state"
          chmod 0644 "$state"
        fi
      '';
    };
  };

  ##############################################################
  ## Power management / lid-close suspend
  ##############################################################
  services.logind = {
    settings = {
      Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";
        HandleLidSwitchDocked = "ignore";
        HandlePowerKey = "suspend";
      };
    };
  };

  ##############################################################
  ## Audio
  ##############################################################
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ── Bluetooth ──
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  ##############################################################
  ## Thunar automount support: NTFS drives + MTP phones
  ##############################################################
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  ##############################################################
  ## Ollama (local AI models)
  ##############################################################
  services.ollama = {
    enable = true;
    host = "127.0.0.1";
    port = 11434;
  };

  ##############################################################
  ## User
  ##############################################################
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "wheel" "networkmanager" "video" "input" "docker" ];
    shell = pkgs.zsh;
  };

  ##############################################################
  ## Docker
  ##############################################################
  virtualisation.docker.enable = true;

  programs.zsh.enable = true;

  # User-space FUSE mounts (rclone Google Drive at ~/Documents):
  # sets user_allow_other in /etc/fuse.conf so non-root mounts work.
  programs.fuse.userAllowOther = true;

  ##############################################################
  ## System packages
  ##############################################################
  # NOTE: firefox is provided by programs.firefox.enable; ollama by
  # services.ollama.enable — neither is listed here to avoid duplication.
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    waybar
    pciutils
    gnome-keyring
    sqlite
    appimage-run
    # nh renders nvd package diffs after each `nh os switch`; this nixpkgs's
    # programs.nh module has no nvd.enable option, so add it explicitly.
    nvd
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    font-awesome
  ];

  # Firefox wrapped with the Widevine CDM path (Linux VMP exemption — CDM from
  # pkgs.widevine-cdm, copied to ~/.widevine-cdm by home.nix). Prefs locked so
  # DRM (Netflix/Prime/Spotify) keeps working after browser profile resets.
  programs.firefox = {
    enable = true;
    package = pkgs.firefox.override {
      extraPrefs = ''
        lockPref("media.gmp-widevinecdm.enabled", true);
        lockPref("media.gmp-widevinecdm.path", "${config.users.users.${username}.home}/.widevine-cdm");
      '';
    };
  };

  ##############################################################
  ## Power profiles (balanced / power-saver / performance —
  ## the Windows-battery-slider equivalent for this laptop)
  ##############################################################
  services.power-profiles-daemon.enable = true;

  ##############################################################
  ## Virtual camera (v4l2loopback) for OBS virtual-camera output
  ##############################################################
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = "options v4l2loopback exclusive_caps=1";

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  system.stateVersion = "26.05";
}
