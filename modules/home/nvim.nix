{ config, pkgs, lib, ... }:

let
  # ── LazyVim + lazy.nvim fully from nixpkgs vimPlugins ──
  # Everything ships from the nix store: lazy.nvim's `dev.path` points at this
  # symlink farm, so no plugin is ever git-cloned at runtime.
  # runCommand (not buildEnv): plugins may share root files like `.neoconf.json`
  # (LazyVim + lazy.nvim) which buildEnv rejects as collisions.
  pluginsList = with pkgs.vimPlugins; [
    # core (LazyVim + lazy.nvim + UI)
    lazy-nvim
    LazyVim
    snacks-nvim
    flash-nvim
    which-key-nvim
    trouble-nvim
    gitsigns-nvim
    todo-comments-nvim
    grug-far-nvim
    bufferline-nvim
    noice-nvim
    nvim-notify
    nui-nvim
    lualine-nvim
    mini-nvim          # mini.ai / mini.pairs / mini.icons / ...
    lazydev-nvim
    ts-comments-nvim
    nvim-web-devicons
    # lsp / format / lint
    # NOTE: no mason* — LSP binaries (rust-analyzer, pyright, ruff, nil,
    # vtsls) come from home.packages on PATH, so nothing is downloaded at
    # runtime. LazyVim guards all mason code behind LazyVim.has("mason.nvim").
    nvim-lspconfig
    conform-nvim
    nvim-lint
    nvim-treesitter.withAllGrammars  # "all the bells" — every parser
    # completion + snippets (blink is LazyVim 15's default engine)
    blink-cmp
    blink-compat
    nvim-snippets
    friendly-snippets
    # codebase navigation / editing
    telescope-nvim
    telescope-fzf-native-nvim
    plenary-nvim
    indent-blankline-nvim
    vim-repeat
    # testing + debugging
    neotest
    neotest-python
    nvim-nio
    nvim-dap
    nvim-dap-ui
    nvim-dap-python
    venv-selector-nvim
    # rust extras
    rustaceanvim
    crates-nvim
  ];

  pluginFarm = pkgs.runCommand "lazyvim-plugins" { } (
    "mkdir -p $out\n" +
    lib.concatMapStringsSep "\n" (p: "ln -s ${p} $out/${p.pname}")
      pluginsList
  );

  # ── LazyVim specs reference split mini.* repos (mini.ai, mini.icons, …)
  #    but nixpkgs ships the monorepo dir `mini.nvim`. Add alias symlinks so
  #    lazy.nvim's dev-path lookup finds every module. ──
  miniAliases = [
    "mini.ai" "mini.animate" "mini.comment" "mini.diff" "mini.files"
    "mini.hipatterns" "mini.icons" "mini.indentscope" "mini.move"
    "mini.pairs" "mini.snippets" "mini.starter" "mini.surround" "mini.nvim"
  ];

  devFarm = pkgs.runCommand "lazyvim-dev" { } ''
    mkdir -p $out
    for p in $(ls ${pluginFarm}); do
      ln -s ${pluginFarm}/$p $out/$p
    done
    for m in ${lib.concatStringsSep " " miniAliases}; do
      ln -sfn ${pluginFarm}/mini.nvim $out/$m
    done
  '';
in
{
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

    # LazyVim must load before our lazy.setup() so it bootstraps the specs
    plugins = with pkgs.vimPlugins; [ lazy-nvim LazyVim ];

    initLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "

      -- lazy.nvim's setup() runs `vim.go.loadplugins = false`, which makes nvim
      -- drop the pack/*/start/* glob from runtimepath. Prepend lazy.nvim's own
      -- path so its modules (e.g. lazy.view.commands in headless mode) stay
      -- resolvable for the whole setup.
      vim.opt.rtp:prepend("${pkgs.vimPlugins.lazy-nvim}")

      local lazypath = "${devFarm}"
      require("lazy").setup({
        spec = {
          { "LazyVim/LazyVim", import = "lazyvim.plugins", opts = {
            colorscheme = "catppuccin",
          } },

          -- ── Language extras ──
          { import = "lazyvim.plugins.extras.lang.rust" },
          { import = "lazyvim.plugins.extras.lang.python" },
          { import = "lazyvim.plugins.extras.lang.nix" },
          { import = "lazyvim.plugins.extras.lang.json" },
          { import = "lazyvim.plugins.extras.lang.markdown" },
          { import = "lazyvim.plugins.extras.lang.typescript" },

          -- ── Editing / navigation / testing ──
          { import = "lazyvim.plugins.extras.editor.mini-files" },
          { import = "lazyvim.plugins.extras.editor.harpoon2" },
          { import = "lazyvim.plugins.extras.coding.mini-comment" },
          { import = "lazyvim.plugins.extras.coding.mini-surround" },
          { import = "lazyvim.plugins.extras.ui.mini-indentscope" },
          { import = "lazyvim.plugins.extras.test.core" },
          { import = "lazyvim.plugins.extras.dap.core" },
          { import = "lazyvim.plugins.extras.editor.telescope" },

          -- ── User overrides: themes + nix/rust bootstrapping ──
          { import = "nix" },
        },
        defaults = { lazy = true },
        dev = {
          path = "${devFarm}",
          patterns = { "." },
          fallback = true,
        },
        install = { missing = false },
        checker = { enabled = false },
        performance = {
          cache = { enabled = false },
          rtp = { reset = false, disabled_plugins = {} },
        },
      })
    '';
  };

  # ── User spec module: themes + small tasteful overrides ──
  home.file.".config/nvim/lua/nix.lua".text = ''
    -- Themes — flip with :LazyVimColorscheme (default: catppuccin)
    return {
      { "catppuccin/nvim", name = "catppuccin", priority = 1000, lazy = true },
      { "folke/tokyonight.nvim", name = "tokyonight", priority = 1000, lazy = true },
      { "navarasu/onedark.nvim", name = "onedark", priority = 1000, lazy = true }, -- VS Code vibe
      { "ellisonleao/gruvbox.nvim", name = "gruvbox", priority = 1000, lazy = true },
      { "Mofiqul/dracula.nvim", name = "dracula", priority = 1000, lazy = true },
      { "shaunsingh/nord.nvim", name = "nord", priority = 1000, lazy = true },
      { "EdenEast/nightfox.nvim", name = "nightfox", priority = 1000, lazy = true },
      { "rakr/vim-one", name = "vim-one", priority = 1000, lazy = true },

      -- rust-analyzer from PATH (already in home.packages), no mason download
      { "mrcjkb/rustaceanvim", opts = { server = {
        on_attach = function(_, _)
          vim.keymap.set("n", "<leader>cR", function() vim.cmd.RustLsp("codeAction") end, { desc = "Code Action" })
        end,
      } } },
    }
  '';
}