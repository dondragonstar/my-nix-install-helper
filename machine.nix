# ══════════════════════════════════════════════════════════════════
# THE machine-identity file. ALL machine-specific values live here
# (plus auto-generated hardware-configuration.nix). Nothing
# machine-specific may be hardcoded anywhere else — AGENTS.md rule.
# bootstrap.sh rewrites this file when installing on a new machine.
# ══════════════════════════════════════════════════════════════════
{
  hostname = "hydragon2000-pc";
  username = "hydragon2000";
  timezone = "Asia/Kolkata";

  # intel | amd | unknown — selects CPU microcode updates
  cpu = "intel";

  # One of: nvidia | amd | intel | hybrid-nvidia | vm | generic
  # (validated at eval time in flake.nix — a typo gives a clear error)
  gpu = "hybrid-nvidia";

  # Only used when gpu = "hybrid-nvidia" (PRIME offload bus IDs).
  # Key is intelBusId or amdgpuBusId depending on the iGPU vendor.
  nvidiaBusIds = {
    intelBusId = "PCI:0@0:2:0";
    nvidiaBusId = "PCI:1@0:0:0";
  };
}
