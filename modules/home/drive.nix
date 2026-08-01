{ config, pkgs, lib, username, hostname, wlctl, ... }:

{
  # ── Google Drive "IMPORTANT DOCS" folder mounted at ~/Documents ──
  # Folder pinned by ID (rename-proof): gdrive:1CuBbmy9f55DfEnBdSbBFe_geFRROweNd
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
      ExecStart = "${pkgs.rclone}/bin/rclone mount gdrive:1CuBbmy9f55DfEnBdSbBFe_geFRROweNd %h/Documents --vfs-cache-mode full --vfs-cache-max-size 10G --poll-interval 15s";
      ExecStop = "${pkgs.fuse3}/bin/fusermount3 -u %h/Documents";
      Restart = "on-failure";
      RestartSec = "10";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
