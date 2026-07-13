{ config, lib, pkgs, hostname, username, ... }:

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

  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  ##############################################################
  ## Networking
  ##############################################################
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  ##############################################################
  ## Time / Locale
  ##############################################################
  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_US.UTF-8";

  ##############################################################
  ## Nix settings
  ##############################################################
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    extra-substituters = [
      "https://walker.cachix.org"
      "https://walker-git.cachix.org"
    ];
    extra-trusted-public-keys = [
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
    ];
  };
  nixpkgs.config.allowUnfree = true;

  ##############################################################
  ## Graphics / NVIDIA
  ## MACHINE-SPECIFIC (section below) — edit or remove for different HW.
  ## This laptop uses NVIDIA RTX 2050 + Intel iGPU (Optimus PRIME offload).
  ## For a different GPU (AMD, Intel-only, etc.), replace accordingly.
  ##############################################################
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };

      intelBusId = "PCI:0@0:2:0";
      nvidiaBusId = "PCI:1@0:0:0";
    };
  };

  ##############################################################
  ## Hyprland (via nixpkgs module)
  ##############################################################
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  ##############################################################
  ## Display manager
  ##############################################################
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = username;
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
  ## Ollama (local AI models)
  ##############################################################
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
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

  ##############################################################
  ## System packages
  ##############################################################
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    waybar
    firefox
    pciutils
    ollama
    gnome-keyring
    appimage-run
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    font-awesome
  ];

  programs.firefox.enable = true;

  services.gnome.gnome-keyring.enable = true;

  system.stateVersion = "26.05";
}
