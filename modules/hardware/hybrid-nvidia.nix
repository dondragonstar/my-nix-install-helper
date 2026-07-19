# NVIDIA dGPU + iGPU laptop (PRIME render offload).
# Bus IDs come from machine.nix (nvidiaBusIds), so this file is portable.
{ config, pkgs, machine, ... }:

{
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    powerManagement = {
      enable = true;
      finegrained = true;
    };

    # offload settings + whichever bus IDs machine.nix provides
    # (intelBusId or amdgpuBusId, plus nvidiaBusId)
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
    } // machine.nvidiaBusIds;
  };

  # CUDA build of Ollama only makes sense on NVIDIA hardware
  services.ollama.package = pkgs.ollama-cuda;
}
