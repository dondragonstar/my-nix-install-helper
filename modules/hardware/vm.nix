# Virtual machine guest (virtio-gpu / QXL / VMware SVGA).
# Kernel modesetting drives the display; add guest integration agents.
{ machine, ... }:

{
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
}
