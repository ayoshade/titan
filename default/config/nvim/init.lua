-- Original Titan editor defaults: no plugin bootstrap or network access.
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.smartindent = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.undofile = true
vim.opt.clipboard = "unnamedplus"
vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { desc = "Save file" })
vim.keymap.set("n", "<leader>e", "<cmd>Explore<cr>", { desc = "File browser" })
vim.keymap.set("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear search" })
local function theme()
  local state = vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")
  local file = io.open(state .. "/titan/generated/palette.json", "r")
  if not file then return end
  local ok, p = pcall(vim.json.decode, file:read("*a"))
  file:close()
  if not ok then return end
  vim.api.nvim_set_hl(0, "Normal", { fg = p.text, bg = p.background })
  vim.api.nvim_set_hl(0, "NormalFloat", { fg = p.text, bg = p.surface })
  vim.api.nvim_set_hl(0, "Comment", { fg = p.muted, italic = true })
  vim.api.nvim_set_hl(0, "Visual", { bg = p.raised })
  vim.api.nvim_set_hl(0, "CursorLine", { bg = p.surface })
  vim.api.nvim_set_hl(0, "LineNr", { fg = p.muted })
  vim.api.nvim_set_hl(0, "StatusLine", { fg = p.accent, bg = p.surface })
  for _, name in ipairs({ "Function", "Keyword", "Type", "Identifier" }) do
    vim.api.nvim_set_hl(0, name, { fg = p.accent })
  end
end
theme()
vim.api.nvim_create_autocmd("FocusGained", { callback = theme })
