# Single NVIDIA GPU (desktop) — no PRIME offload.
{ config, pkgs, machine, ... }:

{
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
  };

  services.ollama.package = pkgs.ollama-cuda;
}
