{ config, lib, pkgs, hostname, username, machine, hyprland, xdph, ... }:

{
  imports = [
    ./modules/system/plymouth.nix
    ./modules/system/omarchy-boot.nix
  ];
  # hardware-configuration.nix is imported via flake.nix's modules list,
  # not here -- this avoids the duplicate-import trap some tutorials cause
  # when both flake.nix and configuration.nix reference it.

  ##############################################################
  ## Boot / Bootloader
  ##############################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 3;

  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    "systemd.show_status=auto"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=auto"
  ];

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
    # uwsm opt-in — flip to true for Omarchy `uwsm start Hyprland` session flow;
    # already handled by `systemctl --user import-environment` in hyprland.lua, so false is safe default (Task 4)
    withUWSM = false;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  ##############################################################
  ## Input / Key remapping (keyd — disabled per user request;
  ## caps→esc removed so Caps Lock returns to normal / disabled)
  ##############################################################
  services.keyd.enable = false;

  ##############################################################
  ## Login greeter (SDDM catppuccin-mocha — Omarchy parity)
  ##
  ## Customizable: change theme to another catppuccin-sddm flavour
  ## or add extraPackages for more themes.
  ##############################################################
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "catppuccin-mocha-mauve";
    extraPackages = with pkgs; [ catppuccin-sddm ];
    settings.Theme.FacesDir = "/run/current-system/sw/share/sddm/faces";
    autoNumlock = true;
  };
  services.displayManager.defaultSession = "hyprland";

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

  # No DE polkit agent in session → auto-authorize user for disk mounts
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
           action.id == "org.freedesktop.udisks2.filesystem-mount-other-seat" ||
           action.id == "org.freedesktop.udisks2.filesystem-mount") &&
          subject.user == "${username}") {
        return polkit.Result.YES;
      }
    });
  '';

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
  security.pam.services.sddm.enableGnomeKeyring = true;

  # PAM service for the quickshell lock screen (lockshell.nix) — unix
  # password auth, same shape omarchy provisions as omarchy-lock-password.
  security.pam.services.hydra-lock = { };

  system.stateVersion = "26.05";
}
