{ ... }: {
  boot.plymouth = {
    enable = true;
    theme = "bgrt";
    themePackages = [];
  };
  boot.initrd.systemd.enable = true;
}
