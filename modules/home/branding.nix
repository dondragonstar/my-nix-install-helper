{ pkgs, ... }: {
  home.file.".local/bin/hydra-branding-preview" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      bg=''${1:-'#1d2021'}; fg=''${2:-'#ebdbb2'}; src=''${3:-$HOME/.config/branding/screensaver.txt}
      out=''${4:-/tmp/preview.png}
      font="${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf"
      convert -background "$bg" -fill "$fg" -font "$font" -pointsize 18 label:@"$src" "$out" && echo "preview $out"
    '';
  };
  home.file.".local/bin/hydra-branding-sync" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      cp "$HOME/.config/branding/screensaver.txt" /etc/nixos/assets/branding/screensaver.txt
      echo "synced → review git diff → build (nh os build)"
    '';
  };
}
