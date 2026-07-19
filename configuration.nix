{ config, lib, pkgs, hostname, username, machine, ... }:

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
    ];
    extra-trusted-public-keys = [
      "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
      "walker-git.cachix.org-1:vmC0ocfPWh0S/vRAQGtChuiZBTAe4wiKDeyyXM0/7pM="
    ];
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
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
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
    sqlite
    appimage-run
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    font-awesome
  ];

  programs.firefox.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.sddm-autologin.enableGnomeKeyring = true;

  system.stateVersion = "26.05";
}
