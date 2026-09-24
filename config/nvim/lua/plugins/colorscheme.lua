-- Catppuccin Mocha —— 与终端（Ghostty/Kitty/Alacritty）、Zed、Herdr 等保持一致
-- 说明：AstroNvim 默认的 astrodark 不在 Catppuccin 体系内，这里显式换成 catppuccin。
-- 需要 `nvim --headless '+Lazy! install' +qa`（或 :Lazy install）拉取 catppuccin/nvim。

---@type LazySpec
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      -- 跟随终端报告的亮/暗切换（与 Zed 的 Catppuccin Latte / Mocha 对齐）
      background = { light = "latte", dark = "mocha" },
      -- 透出 Ghostty 的 background-opacity，与 polish.lua 里对各高亮组的透明处理一致
      transparent_background = true,
    },
  },
  -- AstroUI 只负责 `:colorscheme <name>`，名字对上即可
  { "AstroNvim/astroui", opts = { colorscheme = "catppuccin" } },
}
