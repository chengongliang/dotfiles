-- This will run last in the setup process.

-- 终端背景透明 (匹配 Ghostty background-opacity = 0.8)
-- 让 Neovim 不设置背景色，透出终端透明度
-- 需要同时处理：普通窗口、非焦点窗口、浮动窗口、Neo-tree 专用高亮组
vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    local transparent_groups = {
      "Normal",
      "NormalNC",             -- 非当前窗口（焦点切到左侧后右侧用这个）
      "NormalFloat",          -- 浮动窗口
      "NeoTreeNormal",        -- Neo-tree 当前窗口
      "NeoTreeNormalNC",      -- Neo-tree 非当前窗口
      "NeoTreeFloatNormal",   -- Neo-tree 浮动窗口
      "NeoTreeCursorLine",    -- Neo-tree 光标行（保持选中高亮但背景透明）
      "WinSeparator",         -- 窗口分割线
      "FloatBorder",          -- 浮动窗口边框
    }
    for _, group in ipairs(transparent_groups) do
      vim.api.nvim_set_hl(0, group, { bg = "none" })
    end
    -- 保留光标行的下划线/加粗效果，只去掉背景色
    vim.api.nvim_set_hl(0, "CursorLine", { bg = "none" })
  end,
})
-- 立即执行一次
local transparent_groups = {
  "Normal",
  "NormalNC",
  "NormalFloat",
  "NeoTreeNormal",
  "NeoTreeNormalNC",
  "NeoTreeFloatNormal",
  "NeoTreeCursorLine",
  "WinSeparator",
  "FloatBorder",
}
for _, group in ipairs(transparent_groups) do
  vim.api.nvim_set_hl(0, group, { bg = "none" })
end
vim.api.nvim_set_hl(0, "CursorLine", { bg = "none" })
