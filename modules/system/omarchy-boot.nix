{ config, pkgs, lib, ... }:
let
  omarchyTheme = pkgs.stdenv.mkDerivation {
    name = "plymouth-theme-omarchy";
    src = ../../themes/omarchy;
    installPhase = ''
      mkdir -p $out/share/plymouth/themes/omarchy
      cp -r bullet.png entry.png lock.png logo.png omarchy.plymouth omarchy.script progress_bar.png progress_box.png $out/share/plymouth/themes/omarchy/
      sed -i 's|/usr/share/|/share/|g' $out/share/plymouth/themes/omarchy/*
    '';
  };
  catppuccin-sddm-large = pkgs.runCommand "catppuccin-sddm-1.1.2-large" {} ''
    mkdir -p $out/share/sddm/themes
    cp -r ${pkgs.catppuccin-sddm}/share/sddm/themes/* $out/share/sddm/themes/
    chmod -R u+w $out/share/sddm/themes
    for f in $out/share/sddm/themes/catppuccin-*/theme.conf; do
      [ -f "$f" ] && sed -i 's/^FontSize=.*/FontSize=11/' "$f"
    done
  '';
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

  services.displayManager.sddm.extraPackages = lib.mkForce [ catppuccin-sddm-large ];
}