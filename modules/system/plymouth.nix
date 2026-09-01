{ pkgs, ... }:
let
  brandingSrc = ../../assets/branding/screensaver.txt;
  jetbrainsMono = pkgs.nerd-fonts.jetbrains-mono;
  fontFile = "${jetbrainsMono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf";
  logoPng = pkgs.runCommand "hydra-logo.png" {
    buildInputs = [ pkgs.imagemagick ];
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ jetbrainsMono ]; };
  } ''convert -background '#1d2021' -fill '#ebdbb2' -font "${fontFile}" -pointsize 18 label:@"${brandingSrc}" $out'';
  hydraTheme = pkgs.runCommand "plymouth-hydra-theme" {} ''
    mkdir -p $out/share/plymouth/themes/hydra
    cp ${logoPng} $out/share/plymouth/themes/hydra/logo.png
    cat > $out/share/plymouth/themes/hydra/hydra.plymouth <<EOF
[Plymouth Theme]
Name=Hydra
Description=Branding from assets/branding/screensaver.txt
ModuleName=script
[script]
ImageDir=/share/plymouth/themes/hydra
ScriptFile=/share/plymouth/themes/hydra/hydra.script
EOF
    cat > $out/share/plymouth/themes/hydra/hydra.script <<'SCRIPT'
Window.SetBackgroundTopColor(0.11, 0.12, 0.13);
Window.SetBackgroundBottomColor(0.11, 0.12, 0.13);
logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetPosition(Window.GetWidth()/2 - logo.image.GetWidth()/2, Window.GetHeight()/2 - 100, 10000);
SCRIPT
  '';
in {
  boot.plymouth.themePackages = [ hydraTheme ];
  boot.plymouth.theme = "hydra";
  boot.plymouth.enable = true;
  boot.initrd.systemd.enable = true;
}
