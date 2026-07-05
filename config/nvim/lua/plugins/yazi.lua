return {
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
    keys = {
      -- 打开 yazi 在侧边栏
      { "<leader>yy", "<cmd>Yazi<cr>", desc = "Open Yazi (cwd)" },
      -- 打开 yazi 定位到当前文件
      { "<leader>yl", "<cmd>Yazi toggle<cr>", desc = "Toggle Yazi (current file)" },
    },
    opts = {
      open_for_directories = false,
      keymaps = {
        show_help = "<f1>",
      },
    },
  },
}
