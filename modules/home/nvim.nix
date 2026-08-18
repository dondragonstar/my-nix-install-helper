{ config, pkgs, lib, ... }:

{
  # LSP / tooling binaries stay on PATH so a future LSP setup needs no
  # mason downloads.
  home.packages = with pkgs; [
    lazygit
    pyright
    ruff
    nil
    nixfmt
    statix
    vtsls
    python3Packages.debugpy  # provides `debugpy-adapter` for dap-python
  ];

  programs.neovim = {
    enable = true;
    vimAlias = true;
    viAlias = true;
    defaultEditor = true;

    extraLuaConfig = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.termguicolors = true
      vim.opt.mouse = "a"
      vim.opt.scrolloff = 8

      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.smartindent = true

      vim.opt.splitright = true
      vim.opt.splitbelow = true
      vim.opt.swapfile = false
      vim.opt.undofile = true
      vim.opt.clipboard = "unnamedplus"
      vim.opt.signcolumn = "yes"
    '';
  };
}