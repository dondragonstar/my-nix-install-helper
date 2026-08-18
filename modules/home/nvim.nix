{ config, pkgs, lib, ... }:

# Nix-pinned hybrid Neovim: lazy.nvim is the ONLY rtp-loaded plugin (bootstraps
# itself from the nix store). Every other plugin is handed to lazy.nvim as a
# `{ dir = <nix-store-path> }` spec — lazy derives the name from the store
# basename and handles load order + rtp. No git clones, no runtime downloads:
# add/update plugins by editing this list and rebuilding. Rollback = old
# generation. LSP servers stay on PATH (hermetic); mason is UI only.

let
  ts = pkgs.vimPlugins.nvim-treesitter.withAllGrammars; # bundled parsers, hermetic

  # lazy.nvim specs, one per Nix-provided plugin (lazy-nvim itself excluded —
  # it rides the rtp via `plugins` below so init.lua can require it).
  specLines = lib.concatMapStringsSep "\n" (p:
    "  { dir = \"${p}\", },") [
      (with pkgs.vimPlugins; plenary-nvim)
      (with pkgs.vimPlugins; telescope-nvim)
      (with pkgs.vimPlugins; telescope-fzf-native-nvim) # native sort speed (best-effort)
      ts
      (with pkgs.vimPlugins; mason-nvim)
      (with pkgs.vimPlugins; mason-lspconfig-nvim)
      (with pkgs.vimPlugins; flash-nvim)
      (with pkgs.vimPlugins; nvim-surround)
      (with pkgs.vimPlugins; mini-ai)
      (with pkgs.vimPlugins; snacks-nvim)
      (with pkgs.vimPlugins; nvim-web-devicons)
      (with pkgs.vimPlugins; catppuccin-nvim)
      (with pkgs.vimPlugins; lualine-nvim)
      (with pkgs.vimPlugins; which-key-nvim)
      (with pkgs.vimPlugins; gitsigns-nvim)
      (with pkgs.vimPlugins; nvim-autopairs)
      (with pkgs.vimPlugins; comment-nvim)
      (with pkgs.vimPlugins; indent-blankline-nvim)
    ];
in
{
  # LSP / tooling binaries stay on PATH so nothing is downloaded at runtime
  # (rust-analyzer, fzf, lazygit, ripgrep, fd already come from apps.nix).
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

    plugins = with pkgs.vimPlugins; [
      lazy-nvim # loader bootstrap only — everything else via dir specs below
    ];

    initLua = ''
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

      -- ── lazy.nvim bootstrap: Nix-pinned plugin specs ──
      local specs = {
      ${specLines}
      }

      require("lazy").setup(specs, {
        install = { missing = false },           -- never git-clone; nix owns plugins
        checker = { enabled = false },           -- no updater (nix update flow)
        change_detection = { notify = false },
        ui = { border = "rounded" },
      })

      -- ── every pcall guards a plugin: one failure never bricks nvim ──
      local ok_cat, cat = pcall(require, "catppuccin")
      if ok_cat then
        cat.setup({ flavour = "mocha" })
        vim.cmd.colorscheme("catppuccin")
      end

      local ok_lualine, lualine = pcall(require, "lualine")
      if ok_lualine then lualine.setup({ options = { theme = "catppuccin-mocha" } }) end

      local ok_wk, wk = pcall(require, "which-key")
      if ok_wk then
        wk.setup({
          spec = {
            { "<leader>f", group = "find" },
            { "<leader>g", group = "git" },
            { "<leader>c", group = "code" },
          },
        })
      end

      -- ── telescope (replaces fzf-lua) ──
      local ok_tel, tel = pcall(require, "telescope")
      if ok_tel then
        tel.setup({
          defaults = { layout_config = { prompt_position = "top" } },
          extensions = { fzf = {} },
        })
        pcall(tel.load_extension, "fzf") -- native sort; no-op if binary absent
        local tb = require("telescope.builtin")
        vim.keymap.set("n", "<leader>ff", tb.find_files, { desc = "find files" })
        vim.keymap.set("n", "<leader>fg", tb.live_grep, { desc = "live grep" })
        vim.keymap.set("n", "<leader>fb", tb.buffers, { desc = "buffers" })
        vim.keymap.set("n", "<leader>fr", tb.oldfiles, { desc = "recent files" })
        vim.keymap.set("n", "<leader>fh", tb.help_tags, { desc = "help tags" })
        vim.keymap.set("n", "<leader>fs", tb.lsp_document_symbols, { desc = "document symbols" })
      end

      -- ── treesitter: syntax + folding (parsers bundled by nixpkgs) ──
      local ok_ts, tscfg = pcall(require, "nvim-treesitter.configs")
      if ok_ts then
        tscfg.setup({
          ensure_installed = {}, -- never download parsers; nix ships them
          highlight = { enable = true },
          fold = { enable = true },
        })
      end
      vim.opt.foldmethod = "expr"
      vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
      vim.opt.foldlevel = 99
      vim.opt.foldlevelstart = 99

      -- ── flash.nvim: fast motion (s / S, replaces leap) ──
      local ok_flash, flash = pcall(require, "flash")
      if ok_flash then
        flash.setup({}) -- default maps: s char jump, S treesitter jump
        vim.keymap.set({ "n", "x", "o" }, "s", flash.jump, { desc = "flash jump" })
      end

      -- ── nvim-surround: ys/ds/cs quotes, brackets, tags ──
      pcall(require, "nvim-surround")

      -- ── mini.ai: enhanced text objects (ai/ii) ──
      local ok_ai, ai = pcall(require, "mini.ai")
      if ok_ai then ai.setup() end

      -- ── snacks.nvim: dashboard on bare `nvim` ──
      local ok_snacks, snacks = pcall(require, "snacks")
      if ok_snacks then snacks.setup({ dashboard = { preset = "doom" } }) end

      -- ── LSP: servers on PATH (rust-analyzer, pyright), mason = UI only ──
      local ok_mason, mason = pcall(require, "mason")
      if ok_mason then mason.setup({ ui = { border = "rounded" } }) end

      local ok_ml, ml = pcall(require, "mason-lspconfig")
      if ok_ml then
        ml.setup({
          ensure_installed = {},      -- hermetic: no runtime downloads
          automatic_enable = false,   -- don't touch the explicit setups below
        })
      end

      local ok_lsp, lspconfig = pcall(require, "lspconfig")
      if ok_lsp then
        local on_attach = function(_, bufnr)
          local opts = { buffer = bufnr }
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
          vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, opts)
          vim.keymap.set("n", "gf", vim.lsp.buf.format, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
          vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
          vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
          vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)
          vim.keymap.set("n", "<leader>cl", function()
            local ok_t, tbd = pcall(require, "telescope.builtin")
            if ok_t then tbd.diagnostics() else vim.diagnostic.open_float() end
          end, { buffer = bufnr, desc = "list diagnostics" })
          vim.keymap.set("n", "<leader>td", function()
            if vim.diagnostic.is_enabled(0) then vim.diagnostic.disable(0) else vim.diagnostic.enable(0) end
          end, opts)
          vim.keymap.set("n", "<leader>ts", function()
            for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do c.stop() end
          end, opts)
        end
        lspconfig.rust_analyzer.setup({ on_attach = on_attach })
        lspconfig.pyright.setup({ on_attach = on_attach })
        vim.diagnostic.config({ virtual_text = true, update_in_insert = false, signs = true })
      end

      -- ── git signs / hunk preview ──
      local ok_gits, gits = pcall(require, "gitsigns")
      if ok_gits then
        gits.setup({})
        vim.keymap.set("n", "<leader>gp", gits.preview_hunk, { desc = "preview hunk" })
        vim.keymap.set("n", "<leader>gt", gits.toggle_current_line_blame, { desc = "toggle line blame" })
      end

      local ok_ap, ap = pcall(require, "nvim-autopairs")
      if ok_ap then ap.setup() end

      local ok_c, c = pcall(require, "Comment")
      if ok_c then c.setup() end

      local ok_ib, ib = pcall(require, "ibl")
      if ok_ib then ib.setup() end
    '';
  };
}
