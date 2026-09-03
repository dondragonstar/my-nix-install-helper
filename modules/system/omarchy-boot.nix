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
  boot.initrd.systemd.enable = true;
  boot.initrd.availableKernelModules = [ "i915" ];

  boot.plymouth = {
    enable = true;
    theme = lib.mkForce "omarchy";
    themePackages = [ omarchyTheme ];
  };

  services.displayManager.sddm.extraPackages = lib.mkForce [ catppuccin-sddm-large ];
  environment.systemPackages = [ catppuccin-sddm-large pkgs.bibata-cursors ];

  systemd.services.display-manager.environment = {
    XCURSOR_PATH = "${pkgs.bibata-cursors}/share/icons";
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };
}
