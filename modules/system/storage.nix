{ config, lib, pkgs, ... }:

{
  # ── NTFS (Windows partitions) ──
  # Enables the in-kernel ntfs3 driver + ntfs-3g userspace tools so the
  # "Acer" and "New Volume" partitions can be read.
  boot.supportedFilesystems = [ "ntfs" ];

  # ── Removable-media / drive mounting for Thunar ──
  # udisks2: the mount backend — click-to-mount in Thunar's sidebar, no fstab.
  # gvfs:    the daemon + MTP/gphoto2 backends. THIS is what was missing —
  #          previously gvfs was only a home package (client libs, no daemon),
  #          so nothing could actually mount phones or drives.
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # ── Show internal NTFS partitions in file-manager sidebars ──
  # Without this, udisks2 treats internal NTFS drives as "system" and hides
  # them from Thunar/Nautilus Devices. The udev env override exposes them.
  services.udev.extraRules = ''
    SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="ntfs", ENV{UDISKS_SYSTEM}="0", ENV{UDISKS_IGNORE}="0"
  '';

  # ── Force NTFS mounts read-only ──
  # udisks2 mounts NTFS read-write by default. Forcing ro removes any risk of
  # corrupting a Windows partition left in a Fast-Startup / hibernation state.
  # To allow writes later: disable Fast Startup in Windows, then change `ro`
  # to `rw` (or delete this block for udisks2 defaults).
  environment.etc."udisks2/mount_options.conf".text = ''
    [defaults]
    ntfs_defaults=ro,uid=$UID,gid=$GID,windows_names
    ntfs3_defaults=ro,uid=$UID,gid=$GID,windows_names
  '';

  # ── Phone (Android MTP) + NTFS tooling ──
  environment.systemPackages = with pkgs; [
    ntfs3g     # mount.ntfs-3g, ntfsfix, ntfslabel
    libmtp     # MTP device support + udev rules so phones are recognised
    jmtpfs     # userspace MTP mount (fallback / CLI browsing)
  ];
}
