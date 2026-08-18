{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;
    lfs.enable = true;

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

      # All GitHub remotes go over HTTPS — SSH port 22 (and the 443 fallback)
      # are blocked on this network. Auth is routed per-repo by
      # ~/.local/bin/github-cred (see home.file below).
      url."https://github.com/".insteadOf = "git@github.com:";

      credential."https://github.com" = {
        helper = "!~/.local/bin/github-cred";
        useHttpPath = true;
      };
    };
  };

  # ── Personal git identity (applies to all repos except professional) ──
  home.file.".gitconfig-personal".text = ''
    [user]
      name = dondragonstar
      email = dondragonstar@gmail.com
  '';

  # ── Professional git identity and URL rewrite (HTTPS) ──
  home.file.".gitconfig-professional".text = ''
    [user]
      name = DevaJ2005
      email = devajb01@gmail.com

    [url "https://github.com/"]
      insteadOf = git@github-professional:
  '';

  # ── GitHub credential helper: routes tokens by repo owner ──
  # Personal repos (dondragonstar/*) use the token from gh hosts.yml;
  # everything else delegates to `gh auth git-credential` (active account,
  # token in keyring). Git sends the repo path because useHttpPath is set.
  home.file.".local/bin/github-cred" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Git credential helper for github.com — routes credentials by repo owner.
      # dondragonstar/* repos: personal token from ~/.config/gh/hosts.yml.
      # Everything else (DevaJ2005, org repos): delegated to `gh auth git-credential`.
      set -u

      HOSTS_FILE="$HOME/.config/gh/hosts.yml"

      request="$(cat 2>/dev/null || true)"
      host="$(printf '%s\n' "$request" | sed -n 's/^host=//p' | head -n1)"
      path="$(printf '%s\n' "$request" | sed -n 's/^path=//p' | head -n1)"

      [ "$host" = "github.com" ] || exit 0

      if [ "''${path#dondragonstar/}" != "$path" ]; then
        token="$(awk '/^[[:space:]]*dondragonstar:[[:space:]]*$/ { getline; if ($1 == "oauth_token:") print $2 }' "$HOSTS_FILE" 2>/dev/null)"
        [ -n "$token" ] && printf 'username=dondragonstar\npassword=%s\n' "$token"
      else
        printf '%s\n' "$request" | gh auth git-credential "''${1:-get}"
      fi
    '';
  };

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
