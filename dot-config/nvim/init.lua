-- Luna's nvim init
-- luna@night.horse

-- whitespace
vim.o.expandtab = true
vim.o.softtabstop = 4
vim.o.tabstop = 8
vim.o.shiftwidth = 4
vim.o.autoindent = true

-- display
vim.o.relativenumber = true
vim.o.number = true

-- controls
vim.o.mouse = ""
vim.o.ttymouse = ""

-- plugin manager install
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

-- plugins
vim.g.mapleader = " " -- Make sure to set `mapleader` before lazy so your mappings are correct
require("lazy").setup({
    {
        "neoclide/coc.nvim",
        branch = "release",
    },
    "neovim/nvim-lspconfig",
    "tpope/vim-sleuth",
    "folke/neodev.nvim",
    {
        "nvim-lua/lsp-status.nvim",
        config = function()
          require("lsp-status").register_progress()
        end,
    },
    {
        "nvim-lualine/lualine.nvim",
        dependencies = "lsp-status.nvim",
    }, 
})

-- lualine config/start
require('lualine').setup {
  options = {
    icons_enabled = false,
    theme = 'auto',
    component_separators = { left = '|', right = '|'},
    section_separators = { left = '', right = ''},
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {'filename'},
    lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_y = {'progress', require("lsp-status").status_progress},
    lualine_z = {'location'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
}

-- lsp config/start
local nvim_lsp = require("lspconfig")
local lsp_options = {
  before_init = require("neodev.lsp").before_init,
  on_attach = lsp_on_attach,
  flags = {
    debounce_text_changes = 150,
  },
  settings = {

    haskell = {
      formattingProvider = "fourmolu",
    },

    json = {
      validate = {
        enable = true,
      },
    },

    -- The yaml-language-server actually crashes if I do this with nested
    -- tables instead of writing the property name with dots. Incredible.
    -- Anyways this gets me autocomplete for things like GitHub Actions files.
    -- Essential.
    -- https://github.com/redhat-developer/yaml-language-server
    ["yaml.schemaStore.enable"] = true,

    ["rust-analyzer"] = {
      -- Meanwhile, `rust-analyzer` won't recognize `imports.granularity.group`
      -- unless it's formatted *with* nested tables.
      imports = {
        granularity = {
          -- Reformat imports.
          enforce = true,
          -- Create a new `use` statement for each import when using the
          -- auto-import functionality.
          -- https://rust-analyzer.github.io/manual.html#auto-import
          group = "item",
        },
      },
      inlayHints = {
        bindingModeHints = {
          enable = true,
        },
        closureReturnTypeHints = {
          enable = "always",
        },
        expressionAdjustmentHints = {
          enable = "always",
        },
      },
      checkOnSave = {
        -- Get clippy lints
        command = "clippy",
      },
      files = {
        excludeDirs = {
          -- Don't scan nixpkgs on startup -_-
          -- https://github.com/rust-lang/rust-analyzer/issues/12613#issuecomment-1174418175
          ".direnv",
        },
      },
    },

    Lua = {
      runtime = {
        -- For neovim
        version = "LuaJIT",
      },
      diagnostics = {
        globals = { "vim" },
        unusedLocalExclude = { "_*" },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
      format = {
        enable = false,
      },
    },
  },
}

-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
local lsp_servers = {
  "pyright",
  "racket_langserver",
  "rust_analyzer",
  "tsserver",
  "hls",
  "jsonls",
  "yamlls",
  "html",
  "cssls",
  "texlab", -- LaTeX
  "nil_ls", -- Nix: https://github.com/oxalica/nil
  "lua_ls", -- https://github.com/LuaLS/lua-language-server
  "gopls", -- https://github.com/golang/tools/tree/master/gopls
}

for _, lsp in ipairs(lsp_servers) do
  nvim_lsp[lsp].setup(lsp_options[lsp] or {})
end

-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<space>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<space>f', function()
      vim.lsp.buf.format { async = true }
    end, opts)
  end,
})
