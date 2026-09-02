{ pkgs, ... }:
let
  brandingSrc = ../../assets/branding/screensaver.txt;
  jetbrainsMono = pkgs.nerd-fonts.jetbrains-mono;
  fontFile = "${jetbrainsMono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf";
  logoPng = pkgs.runCommand "hydra-logo.png" {
    buildInputs = [ pkgs.imagemagick ];
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ jetbrainsMono ]; };
  } ''convert -background '#1d2021' -fill '#ebdbb2' -font "${fontFile}" -pointsize 18 label:@"${brandingSrc}" $out'';
  boxPng = pkgs.runCommand "plymouth-box.png" { buildInputs = [ pkgs.imagemagick ]; } ''
    convert -size 320x10 xc:none -fill '#3a3a3a' -draw "roundrectangle 0,0 320,10 5,5" $out
  '';
  barPng = pkgs.runCommand "plymouth-bar.png" { buildInputs = [ pkgs.imagemagick ]; } ''
    convert -size 320x10 xc:none -fill '#ebdbb2' -draw "roundrectangle 0,0 320,10 5,5" $out
  '';
  lockPng = pkgs.runCommand "plymouth-lock.png" {
    buildInputs = [ pkgs.imagemagick ];
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ jetbrainsMono ]; };
  } ''convert -size 48x48 xc:none -fill '#ebdbb2' -gravity center -font "${fontFile}" -pointsize 32 -annotate +0+2 "●" $out'';
  entryPng = pkgs.runCommand "plymouth-entry.png" { buildInputs = [ pkgs.imagemagick ]; } ''
    convert -size 320x30 xc:none -fill '#2a2a2a' -draw "roundrectangle 0,0 320,30 8,8" -fill none -stroke '#3a3a3a' -strokewidth 1 -draw "roundrectangle 1,1 319,29 8,8" $out
  '';
  bulletPng = pkgs.runCommand "plymouth-bullet.png" { buildInputs = [ pkgs.imagemagick ]; } ''
    convert -size 12x12 xc:none -fill '#ebdbb2' -draw "circle 6,6 6,1" $out
  '';
  hydraTheme = pkgs.runCommand "plymouth-hydra-theme" {} ''
    mkdir -p $out/share/plymouth/themes/hydra
    cp ${logoPng} $out/share/plymouth/themes/hydra/logo.png
    cp ${boxPng} $out/share/plymouth/themes/hydra/box.png
    cp ${barPng} $out/share/plymouth/themes/hydra/bar.png
    cp ${lockPng} $out/share/plymouth/themes/hydra/lock.png
    cp ${entryPng} $out/share/plymouth/themes/hydra/entry.png
    cp ${bulletPng} $out/share/plymouth/themes/hydra/bullet.png
    cat > $out/share/plymouth/themes/hydra/hydra.plymouth <<EOF
[Plymouth Theme]
Name=Hydra
Description=Branding from assets/branding/screensaver.txt + Omarchy bar
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
box.image = Image("box.png");
box.sprite = Sprite(box.image);
box.sprite.SetPosition(Window.GetWidth()/2 - box.image.GetWidth()/2, Window.GetHeight() * 0.72, 10000);
bar.original_image = Image("bar.png");
bar.sprite = Sprite();
bar.sprite.SetPosition(Window.GetWidth()/2 - bar.original_image.GetWidth()/2, Window.GetHeight() * 0.72, 10001);
lock.image = Image("lock.png");
lock.sprite = Sprite(lock.image);
lock.sprite.SetPosition(Window.GetWidth()/2 - lock.image.GetWidth()/2, Window.GetHeight() * 0.72 - 50, 10000);
lock.sprite.SetOpacity(0);
entry.image = Image("entry.png");
entry.sprite = Sprite(entry.image);
entry.sprite.SetPosition(Window.GetWidth()/2 - entry.image.GetWidth()/2, Window.GetHeight() * 0.72, 10000);
entry.sprite.SetOpacity(0);
bullet.image = Image("bullet.png");
bullet.sprites = [];
for (i = 0; i < 16; i++) {
  b = Sprite(bullet.image);
  b.SetPosition(Window.GetWidth()/2 - 90 + i * 12, Window.GetHeight() * 0.72 + 9, 10002);
  b.SetOpacity(0);
  bullet.sprites[i] = b;
}
fun progress_callback(duration, progress) {
  bar.image = bar.original_image.Scale(bar.original_image.GetWidth() * progress, bar.original_image.GetHeight());
  bar.sprite.SetImage(bar.image);
}
Plymouth.SetBootProgressFunction(progress_callback);
message.text = "";
message.sprite = Sprite();
message.sprite.SetPosition(Window.GetWidth()/2, Window.GetHeight() * 0.78, 10001);
fun message_callback(text) {
  message.text = text;
}
Plymouth.SetMessageFunction(message_callback);
fun password_callback() {
  box.sprite.SetOpacity(0);
  bar.sprite.SetOpacity(0);
  lock.sprite.SetOpacity(1);
  entry.sprite.SetOpacity(1);
}
Plymouth.SetPasswordFunction(password_callback);
SCRIPT
  '';
in {
  boot.plymouth.themePackages = [ hydraTheme ];
  boot.plymouth.theme = "hydra";
  boot.plymouth.enable = true;
  boot.initrd.systemd.enable = true;
}
