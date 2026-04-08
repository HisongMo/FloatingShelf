<div align="center">

# 🗂️ FloatingShelf — 悬浮架

**一款为 macOS 打造的极简浮窗效率工具**

按住快捷键，文件架与应用启动器即刻浮现于鼠标旁 —— 悬停选择，松键即开，全程零点击。

[![Platform](https://img.shields.io/badge/Platform-macOS%2026%2B-blue?logo=apple)](https://www.apple.com/macos/)
[![Language](https://img.shields.io/badge/Language-Swift%205.9-orange?logo=swift)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](./LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen)](https://github.com/HisongMo/FloatingShelf/releases/tag/v1.0.0)
[![Download](https://img.shields.io/badge/Download-v1.0.0%20.dmg-8A2BE2?logo=github)](https://github.com/HisongMo/FloatingShelf/releases/download/v1.0.0/FloatingShelf_v1.0.0.dmg)

</div>

---

## 🎬 演示展示

| 文件架 | 应用启动器 |
|--------|------------|
| ![文件架演示 1](./Display/2026-04-08%2009.19.27.gif) | ![应用启动器演示 1](./Display/2026-04-08%2009.40.37.gif) |
| ![文件架演示 2](./Display/2026-04-08%2009.42.28.gif) | ![应用启动器演示 2](./Display/2026-04-08%2009.42.47.gif) |

---

## 🎯 解决了哪些痛点？

| 痛点场景 | FloatingShelf 的解法 |
|---------|---------------------|
| 做设计/写文章时，需要频繁在多个 Finder 窗口间穿梭传递素材文件 | **文件架**：把常用文件一次性拖进去，随用随取，无需切换窗口 |
| Launchpad 或 Spotlight 打开 App 步骤繁琐，尤其在全屏模式下 | **应用启动器**：按住快捷键，瞬间呼出带搜索的 App 网格 |
| 找到想打开的文件/应用后还要点击鼠标，打断了键盘流 | **长按–悬停–释放**交互：无需任何鼠标点击，松开按键即触发 |
| 系统应用显示英文名（Notes、Calculator），中文用户难以识别 | 自动提取并展示**中文本地化名称**（如"备忘录"、"计算器"） |
| 效率工具本身占用大量内存/CPU，反而拖慢工作流 | 纯原生 Swift + SwiftUI 开发，**极低资源占用**，常驻菜单栏无感知 |

---

## ✨ 核心功能

### 🗂️ 文件悬浮架（File Shelf）

> 桌面上的"临时口袋"，解决跨应用文件流转的痛点

- **拖拽即存**：从 Finder、浏览器或任意应用直接将文件拖入悬浮架，实现跨窗口无缝暂存
- **智能动态布局**：根据文件数量自动计算最佳列数（1 列到 5 列），窗口始终居中于屏幕
- **随手轻笔记**：右键点击文件可添加自定义备注或设置显示别名，在海量素材中快速定位目标
- **文件直达操作**：悬浮架内直接打开文件、在 Finder 中定位、或一键移除，简化所有操作路径
- **自动持久化**：文件列表在应用重启后自动恢复，并过滤已删除的失效文件

### 🚀 应用启动器（App Launcher）

> 比 Launchpad 更快、更直观的应用中心

- **全域扫描**：自动识别 `/Applications` 和 `/System/Applications`（含各子目录工具）下的所有 App
- **中文化精准适配**：完美提取并显示系统应用的中文本地化名称，彻底消除命名识别障碍
- **实时搜索**：输入关键词即时过滤 App，同时支持中英文名称检索
- **多种翻页方式**：
  - 触控板双指轻扫翻页
  - 键盘 ← → 方向键切换
  - 鼠标滚轮滚动
- **7×3 分页网格**：每页展示 21 个 App，底部圆点实时指示当前页码

### ⌨️ 交互革新：长按–释放 逻辑

FloatingShelf 抛弃传统「点击-等待-点击」模式，引入全新的**瞬时交互系统**：

```
① 按住快捷键   →   悬浮架即刻出现于鼠标位置
② 移动鼠标悬停 →   目标图标放大 + 光晕动效（物理弹簧动画）
③ 松开快捷键   →   自动打开文件 / 启动应用
```

**"一按、一扫、一放"** — 全程无需鼠标点击，操作流畅如飞。

### 🎨 Liquid Glass 视觉设计

紧随 macOS 26 最新设计潮流，采用 **流光玻璃（Liquid Glass）** 视觉方案：

- 背景融合动态导视、边缘高光与磨砂质感，呈现通透的未来感
- 拖入文件时边框呈现流动色彩渐变，给予实时视觉确认
- 原生支持深色与浅色模式，UI 始终保持优雅

### ⚙️ 设置与系统集成

- **开机自启**：支持开机自动启动（Launch at Login）
- **自定义快捷键**：文件架与应用启动器的快捷键可独立设置（默认：⌥D / ⌥A）
- **菜单栏常驻**：以菜单栏图标形式运行，不占用 Dock 空间
- **外观主题**：支持 Liquid Glass 黑/白主题切换
- **文件管理**：设置页面可批量清理失效文件或一键清空文件架

---

## 📋 系统要求

| 项目 | 要求 |
|------|------|
| **操作系统** | macOS 26.0（Tahoe）或更高版本 |
| **芯片架构** | Apple Silicon（M 系列）|
| **磁盘空间** | < 10 MB |
| **权限** | 辅助功能权限（首次启动时引导授权）|

---

## 📦 安装方式

### 方式一：直接下载安装包（推荐）

- **当前版本**：[`v1.0.0`](https://github.com/HisongMo/FloatingShelf/releases/tag/v1.0.0)
- **直接下载**：[`FloatingShelf_v1.0.0.dmg`](https://github.com/HisongMo/FloatingShelf/releases/download/v1.0.0/FloatingShelf_v1.0.0.dmg)
- **Release 页面**：[查看所有版本](https://github.com/HisongMo/FloatingShelf/releases)

安装步骤：

1. 下载最新版 `.dmg` 安装包
2. 打开 `.dmg`，将 `FloatingShelf.app` 拖入 `/Applications` 文件夹
3. 首次启动时，在「系统设置 → 隐私与安全性 → 辅助功能」中授权 FloatingShelf
4. 应用将出现在菜单栏，点击图标开始配置快捷键

### 方式二：从源码编译

**环境要求**：Xcode 15.0+，macOS 26 SDK

```bash
# 克隆仓库
git clone https://github.com/HisongMo/FloatingShelf.git
cd FloatingShelf

# 使用 XcodeGen 生成项目文件（如已有 .xcodeproj 可跳过）
# brew install xcodegen && xcodegen generate

# 用 Xcode 打开并编译
open FloatingShelf.xcodeproj
```

在 Xcode 中选择目标设备为 **My Mac**，按 `⌘R` 运行即可。

---

## 🚀 快速上手

1. **启动应用** — FloatingShelf 图标出现在菜单栏右侧
2. **配置快捷键** — 点击菜单栏图标 → 偏好设置（⌘,）→「快捷键」标签页，录制你的专属热键
3. **添加文件** — 按住文件架快捷键（默认 ⌥D）呼出文件架，将文件从 Finder 拖入
4. **使用文件架** — 按住快捷键，悬停在目标文件上，松开即可打开
5. **启动应用** — 按住应用启动器快捷键（默认 ⌥A），悬停在 App 图标上，松开即启动

---

## 🛠️ 技术栈

| 技术 | 说明 |
|------|------|
| **Swift 5.9** | 主开发语言 |
| **SwiftUI** | 现代声明式 UI 框架 |
| **AppKit / Cocoa** | 窗口管理与系统集成 |
| **Carbon API** | 全局热键注册（无需辅助功能权限） |
| **Combine** | 响应式状态管理 |
| **ServiceManagement** | 开机自启集成 |
| **UniformTypeIdentifiers** | 文件拖放类型识别 |

---

## 📄 许可证

本项目基于 [MIT License](./LICENSE) 开源。

---

<div align="center">

如果 FloatingShelf 对你有帮助，欢迎给项目点个 ⭐ Star！

</div>
