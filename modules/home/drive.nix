{ config, pkgs, lib, username, hostname, wlctl, ... }:

{
  # ── Google Drive "IMPORTANT DOCS" folder mounted at ~/Documents ──
  # Mounted by name, not ID: the folder is a Drive shortcut, so its share-link
  # ID (1CuBbmy9f55DfEnBdSbBFe_geFRROweNd) fails with "directory not found"
  # when passed directly to rclone; the name resolves to the real target.
  # rclone OAuth token lives in ~/.config/rclone/rclone.conf (runtime secret,
  # NOT HM-managed, NOT committed). The service only starts once that config
  # exists (ConditionPathExists) so first boot before `rclone config` is fine.
  systemd.user.services.gdrive-mount = {
    Unit = {
      Description = "Google Drive 'IMPORTANT DOCS' mounted at ~/Documents";
      After = [ "network-online.target" ];
      ConditionPathExists = "%h/.config/rclone/rclone.conf";
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/Documents";
      ExecStart = "${pkgs.rclone}/bin/rclone mount \"gdrive:IMPORTANT DOCS\" %h/Documents --vfs-cache-mode full --vfs-cache-max-size 10G --poll-interval 15s";
      ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u %h/Documents";
      Restart = "on-failure";
      RestartSec = "10";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
