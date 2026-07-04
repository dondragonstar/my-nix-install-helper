{ config, lib, pkgs, ... }:

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

  # NVIDIA's proprietary driver needs the modesetting kernel param.
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  ##############################################################
  ## Networking
  ##############################################################
  networking.hostName = "hydragon2000-pc";
  networking.networkmanager.enable = true;

  # Disable wpa_supplicant explicitly -- NetworkManager owns wifi.
  # networking.wireless.enable = false;

  ##############################################################
  ## Time / Locale
  ##############################################################
  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_US.UTF-8";

  ##############################################################
  ## Nix settings
  ##############################################################
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true; # required for NVIDIA proprietary driver

  ##############################################################
  ## Graphics / NVIDIA (RTX 2050 laptop, Optimus w/ Intel iGPU)
  ##############################################################
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # harmless if unused, needed if you ever run Steam/games
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false; # RTX 2050 (Ampere) -- proprietary driver is the safer default
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # PRIME: laptop has Intel iGPU + NVIDIA dGPU. Offload mode = NVIDIA only
    # spins up on demand (better battery life, good default for a dev laptop).
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # gives you the `nvidia-offload` command
      };

      # Confirmed via Windows Device Manager -> GPU -> Properties -> General -> Location:
      #   Intel:  PCI bus 0, device 2, function 0
      #   NVIDIA: PCI bus 1, device 0, function 0
      intelBusId = "PCI:0@0:2:0";
      nvidiaBusId = "PCI:1@0:0:0";
    };
  };

  ##############################################################
  ## Hyprland (via nixpkgs module, NOT the Hyprland flake)
  ##############################################################
  # Using the nixpkgs-bundled module instead of pulling the Hyprland flake
  # directly avoids forcing a full Hyprland + Mesa + deps rebuild on every
  # `nixos-rebuild switch`. Switch to the flake later once your system is
  # stable and you want bleeding-edge Hyprland features.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Needed for screen share / portals under Hyprland.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  ##############################################################
  ## Display manager
  ##############################################################
  # SDDM as the display manager backend, but autologin (below) skips
  # the login screen entirely and drops straight into Hyprland.
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  # Autologin straight into Hyprland -- no password screen on boot.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "hydragon2000";
  services.displayManager.defaultSession = "hyprland";

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

  ##############################################################
  ## User
  ##############################################################
  users.users.hydragon2000 = {
    isNormalUser = true;
    description = "hydragon2000";
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  ##############################################################
  ## System packages (kept deliberately minimal -- add more via home.nix)
  ##############################################################
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    kitty
    foot
    waybar
    firefox
    pciutils   # generically useful for hardware debugging (lspci, etc.)
    networkmanagerapplet
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    font-awesome
  ];

  programs.firefox.enable = true;

  system.stateVersion = "26.05";
}
