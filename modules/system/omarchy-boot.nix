{ config, pkgs, lib, ... }:
let
  omarchyTheme = pkgs.stdenv.mkDerivation {
    name = "plymouth-theme-omarchy";
    src = ../../themes/omarchy;
    installPhase = ''
      mkdir -p $out/share/plymouth/themes/omarchy
      cp -r bullet.png entry.png lock.png logo.png omarchy.plymouth omarchy.script progress_bar.png progress_box.png $out/share/plymouth/themes/omarchy/
      sed -i "s|/usr/share|$out/share|g" $out/share/plymouth/themes/omarchy/*
    '';
  };
  catppuccin-sddm-large = pkgs.runCommand "catppuccin-sddm-1.1.2-large" {} ''
    mkdir -p $out/share/sddm/themes
    cp -r ${pkgs.catppuccin-sddm}/share/sddm/themes/* $out/share/sddm/themes/
    chmod -R u+w $out/share/sddm/themes
    for f in $out/share/sddm/themes/catppuccin-*/theme.conf; do
      [ -f "$f" ] && sed -i 's/^FontSize=.*/FontSize=11/' "$f"
    done
    for f in $out/share/sddm/themes/catppuccin-*/Components/LoginPanel.qml; do
      [ -f "$f" ] && sed -i \
        -e 's/property var user: userField.text/property var user: userModel.lastUser/' \
        -e '/id: userField/a\      visible: false' \
        -e '/id: sessionPanel/a\      visible: false' \
        "$f"
    done
    for f in $out/share/sddm/themes/catppuccin-*/Components/PowerButton.qml $out/share/sddm/themes/catppuccin-*/Components/RebootButton.qml; do
      [ -f "$f" ] && sed -i \
        -e 's/^    height: inputHeight$/    height: inputHeight * 2/' \
        -e 's/^    width: inputHeight$/    width: inputHeight * 2/' \
        "$f"
    done
  '';
in
{
  boot.initrd.systemd.enable = true;
  boot.initrd.kernelModules = [ "i915" ];

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

  systemd.tmpfiles.rules = [
    "L+ /root/.icons/Bibata-Modern-Classic - - - - ${pkgs.bibata-cursors}/share/icons/Bibata-Modern-Classic"
    "L+ /var/lib/sddm/.icons/Bibata-Modern-Classic - - - - ${pkgs.bibata-cursors}/share/icons/Bibata-Modern-Classic"
  ];
}
