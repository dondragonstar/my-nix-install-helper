{ config, pkgs, lib, ... }:

# Neovim: LazyVim distro, stock starter cloned at ~/.config/nvim (runtime,
# NOT HM-managed). Plugins git-cloned by lazy.nvim on first boot.
# NixOS rule: LSP servers/formatters come from nix (PATH), never Mason
# downloads — see ~/.config/nvim/lua/plugins/nixos.lua override.

{
  # LSP / tooling binaries on PATH so nothing needs runtime downloading.
  # gcc + tree-sitter: nvim-treesitter compiles parsers at runtime (:TSInstall);
  # fzf, ripgrep, fd also available from apps.nix.
  home.packages = with pkgs; [
    lazygit
    pyright
    ruff
    nil
    nixfmt
    statix
    vtsls
    python3Packages.debugpy
    gcc
    tree-sitter
  ];

  programs.neovim = {
    enable = true;
    vimAlias = true;
    viAlias = true;
    defaultEditor = true;
  };
}
