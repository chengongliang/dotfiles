// Catppuccin app themes for Paseo (Mocha / Latte).
// Colors come from the official Catppuccin palette:
// https://github.com/catppuccin/catppuccin#-palette
//
// Mocha (dark) mapping — surfaces get lighter than the background:
//   background -> base        foreground -> text
//   raised     -> surface0    control    -> surface1
//   border     -> surface1    accent     -> mauve
//   mutedForeground -> subtext0            ring -> overlay0
//
// Latte (light) mapping — surfaces get progressively deeper
// (base > mantle > crust > surface0 > surface1):
//   background -> base        foreground -> text
//   raised     -> crust       control    -> mantle
//   border     -> surface0    accent     -> mauve
//   mutedForeground -> subtext0            ring -> overlay0
//
// control 覆盖常驻大面积（侧边栏、输入框、composer、secondary/muted 面），
// 对齐 Zed 的 panel.background=mantle，保持最轻；raised 只用于卡片与 hover 行，
// 用 crust 以保证与 control 底色间仍有一档层次（侧边栏 hover 可见）。
import type { PluginClientContext } from "@getpaseo/plugin/client";

export default function contribute(client: PluginClientContext) {
  client.addTheme({
    id: "mocha",
    name: "Catppuccin Mocha",
    appearance: "dark",
    colors: {
      background: "#1e1e2e",
      foreground: "#cdd6f4",
      raised: "#313244",
      control: "#45475a",
      border: "#45475a",
      accent: "#cba6f7",
      mutedForeground: "#a6adc8",
      ring: "#6c7086",
    },
  });

  client.addTheme({
    id: "latte",
    name: "Catppuccin Latte",
    appearance: "light",
    colors: {
      background: "#eff1f5", // base
      foreground: "#4c4f69", // text
      control: "#e6e9ef", // mantle — sidebar, inputs, composer, muted surfaces
      raised: "#dce0e8", // crust — cards, popovers, hovered rows
      border: "#ccd0da", // surface0
      accent: "#8839ef", // mauve
      mutedForeground: "#6c6f85", // subtext0
      ring: "#9ca0b0", // overlay0
    },
  });

  return () => {};
}
