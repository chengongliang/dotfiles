# Paseo Catppuccin 主题插件

为 [Paseo](https://paseo.sh) 贡献 Catppuccin 外观主题的本地插件（纯数据，无 UI 代码）。

贡献两个主题：

- **Catppuccin Mocha**（dark）—— `background` 等 8 个 token 取自官方色板 base/text/surface0/surface1/mauve/subtext0/overlay0
- **Catppuccin Latte**（light）

Paseo 会把 8 个颜色展开成完整 token 集（面板、菜单、diff、状态色、终端等），
主题出现在 **Settings → Appearance**，与内置主题并列。

> 代码语法高亮另有一项独立设置：**Settings → Syntax → Highlight theme**，
> 内置选项里已有 `catppuccin`，无需插件。

## 安装（daemon 按绝对路径引用本目录）

```bash
# 1. 启用插件系统（~/.paseo/config.json 顶层加 "pluginsEnabled": true）后重载
paseo reload

# 2. 安装本目录
paseo plugin install "$(pwd)"

# 3. 确认
paseo plugin ls
```

修改 `index.client.tsx` 后：

```bash
paseo plugin reload catppuccin
```

## 类型检查（可选）

```bash
npm install
npm run typecheck
```

## 色值对照

核心原则：**深色的表面比背景更亮，浅色的表面比背景逐步更深**（Catppuccin 亮度顺序 `base > mantle > crust > surface0 > surface1`）。

Mocha（dark）：

| Paseo token       | Catppuccin 色板 |
| ----------------- | --------------- |
| `background`      | base            |
| `foreground`      | text            |
| `raised`          | surface0        |
| `control`         | surface1        |
| `border`          | surface1        |
| `accent`          | mauve           |
| `mutedForeground` | subtext0        |
| `ring`            | overlay0        |

Latte（light，对齐 Zed 的 Catppuccin Latte：编辑区=base、panel=mantle）：

| Paseo token       | Catppuccin 色板 | 用途/理由 |
| ----------------- | --------------- | --------- |
| `background`      | base            | 主内容区（同 Zed editor） |
| `foreground`      | text            | |
| `control`         | mantle          | 侧边栏、输入框、composer、muted 面（同 Zed panel），最大面积保持最轻 |
| `raised`          | crust           | 卡片与 hover 行，需与 control 差一档保证层次 |
| `border`          | surface0        | 边框、侧边栏选中项底色 |
| `accent`          | mauve           | |
| `mutedForeground` | subtext0        | |
| `ring`            | overlay0        | |

色板来源：<https://github.com/catppuccin/catppuccin#-palette>
