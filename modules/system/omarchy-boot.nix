{ config, pkgs, lib, ... }:
let
  omarchyTheme = pkgs.stdenv.mkDerivation {
    name = "plymouth-theme-omarchy";
    src = ../../themes/omarchy; # relative to /etc/nixos/ → /tmp/omarchy-basecamp/default/plymouth
    installPhase = ''
      mkdir -p $out/share/plymouth/themes/omarchy
      cp -r bullet.png entry.png lock.png logo.png omarchy.plymouth omarchy.script progress_bar.png progress_box.png $out/share/plymouth/themes/omarchy/
      
      # Wildcard fix for all /usr/share/ paths across .plymouth and .script files
      sed -i 's|/usr/share/|/share/|g' $out/share/plymouth/themes/omarchy/*
    '';
  };
in
{
  boot.plymouth = {
    enable = true;
    theme = lib.mkForce "omarchy";
    themePackages = [ omarchyTheme ];
  };
  
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "splash"
    "quiet"
    "loglevel=3"
    "systemd.show_status=auto"
    "rd.udev.log_level=3"
    "rd.systemd.show_status=auto"
  ];
}