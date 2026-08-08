{ config, pkgs, lib, hostname, ... }:

{
  programs.zsh = {
    # [nh-migration] aliases
    enable = true;
    enableCompletion = true;
    shellAliases = {
      ll = "ls -la";
      rebuild = "/etc/nixos/bin/rebuild";
      drybuild = "nh os build";
      update = "nh os switch --update";
      # nh os boot: apply on next reboot only — current session stays
      # stable if a big upgrade breaks something.
      bootbuild = "nh os boot";
      # Evaluate the flake without building — catches eval errors fast.
      check = "nix flake check /etc/nixos";
      # Manual garbage collect (7d retention) + store dedup.
      gc = "nh clean all";
      gcsize = "nix-store --gc --print-dead | tr '\\n' '\\0' | xargs -0 du -hc | tail -n 1";
      cat = "bat";
      ls = "eza";
      nixup = "python3 /etc/nixos/bin/nixup";
    };
    initContent = ''
      eval "$(starship init zsh)"
      eval "$(zoxide init zsh)"
      source ${pkgs.fzf}/share/fzf/key-bindings.zsh
      source ${pkgs.fzf}/share/fzf/completion.zsh
    '';
  };
}
