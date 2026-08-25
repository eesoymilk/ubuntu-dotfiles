return {
  "nvim-treesitter/nvim-treesitter",
  -- Upstream's default branch is now the rewritten `main`, which drops the
  -- nvim-treesitter.configs API this file uses. Pin the frozen master branch.
  branch = "master",
  build = ":TSUpdate",
  cond = not vim.g.vscode,
  dependencies = {},
  event = { "BufEnter" },
  cmd = { "TSUpdateSync", "TSUpdate", "TSInstall" },
  opts = {
    highlight = { enable = true },
    indent = { enable = true },
    auto_install = true,
    autotag = { enable = true },
    -- latex must be generated from grammar, which needs the tree-sitter CLI
    -- and node at install time. Not worth it: vimtex highlights tex with its
    -- own syntax engine (its recommended setup), and render-markdown degrades
    -- gracefully without the parser. Ignore it so auto_install and every
    -- ensure_installed pass stop erroring on machines without the CLI.
    ignore_install = { "latex" },
    ensure_installed = {
      "bash",
      "c",
      "cpp",
      "html",
      "javascript",
      "svelte",
      "css",
      "json",
      "lua",
      "markdown",
      "markdown_inline",
      "python",
      "query",
      "regex",
      "rust",
      "tsx",
      "typescript",
      "go",
      "yaml",
      "vim",
    },
  },
  config = function(_, opts)
    if type(opts.ensure_installed) == "table" then
      ---@type table<string, boolean>
      local added = {}
      opts.ensure_installed = vim.tbl_filter(function(lang)
        if added[lang] then
          return false
        end
        added[lang] = true
        return true
      end, opts.ensure_installed)
    end
    require("nvim-treesitter.configs").setup(opts)
  end,
}
