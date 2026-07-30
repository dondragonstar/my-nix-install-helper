{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      # No global user — handled by per-directory includes below.
      # Order matters: git processes config top-to-bottom.
      # gitdir:~  matches everything under $HOME; gitdir:~/Projects/professional/ is more specific.
      # For professional repos, both match — personal loads first, professional overrides second.

      includeIf."gitdir:~/Projects/professional/" = {
        path = "~/.gitconfig-professional";
      };

      includeIf."gitdir:~/" = {
        path = "~/.gitconfig-personal";
      };
    };
  };

  # ── Personal git identity (applies to all repos except professional) ──
  home.file.".gitconfig-personal".text = ''
    [user]
      name = dondragonstar
      email = dondragonstar@gmail.com
  '';

  # ── Professional git identity and URL rewrite ──
  home.file.".gitconfig-professional".text = ''
    [user]
      name = DevaJ2005
      email = devajb01@gmail.com

    [url "git@github-professional:"]
      insteadOf = git@github.com:
  '';

  # ── SSH config: pick the right key per account ──
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519_personal";
      };
      "github-professional" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519_professional";
      };
    };
  };
}
