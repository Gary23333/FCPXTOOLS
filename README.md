# 🎬 FCPX 工具箱

<p align="center">
  <img src="assets/AppIcon.iconset/icon_512x512@2x.png" width="140" alt="FCPX 工具箱图标">
</p>

<p align="center">
  <strong>为 Final Cut Pro 用户准备的 macOS 原生工具箱。</strong><br>
  八大功能模块，覆盖清理、模板、健康检查、归档、字幕、输出全流程。
</p>

<p align="center">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-2ea44f"></a>
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2014%2B-0a7ea4">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-f05138">
  <img alt="Version" src="https://img.shields.io/badge/version-v0.4.0-237063">
  <img alt="Electron Prototype" src="https://img.shields.io/badge/Electron-prototype-47848f">
</p>

<p align="center">
  <a href="https://github.com/Gary23333/FCPXTOOLS/releases">📦 下载发布版</a> ·
  <a href="#-快速开始">🚀 快速开始</a> ·
  <a href="#-核心功能">🧰 核心功能</a> ·
  <a href="#-技术栈">🧑‍💻 技术栈</a>
</p>

---

## ✨ 它能帮你做什么

剪 Final Cut Pro 项目久了，资源库里很容易堆满渲染文件、波形缓存、分析缓存、代理媒体和优化媒体。`FCPX 工具箱` 从最初的清理助手出发，现已成长为覆盖 FCPX 全工作流的八合一工具箱——清理缓存、浏览模板、检查健康、归档素材、生成字幕、管理输出，一站式搞定。

```mermaid
flowchart LR
  A["选择 FCPX 资源库或上级目录 📁"] --> B["扫描资源库与事件 🔎"]
  B --> C["按风险展示缓存明细 🧭"]
  C --> D["勾选要清理的项目 ✅"]
  D --> E["移入废纸篓 ♻️"]
  E --> F["释放磁盘空间 🚀"]
```

## 🧰 核心功能

侧边栏按三大分组组织全部 8 个功能模块：

### 🔧 快捷工具

| 模块 | 图标 | 说明 |
| --- | --- | --- |
| **快捷打开** | ⚡ | 一键打开 9 个 FCPX 常用目录（影片目录、Motion 模板、偏好设置、缓存、ProApps 设置、输出目标等），支持直接启动 Final Cut Pro |
| **进程管理** | 📊 | 实时监控 FCPX 运行状态（PID / 内存占用），支持启动 / 退出 / 强制退出，每 2 秒自动刷新 |

### 📦 资源管理

| 模块 | 图标 | 说明 |
| --- | --- | --- |
| **清理助手** | 🧹 | 扫描 `.fcpbundle` 资源库，按风险分级展示缓存，安全移至废纸篓 |
| **模板库** | 🧩 | 浏览 Motion Templates，按效果、转场、字幕/标题、发生器、合成分类，支持搜索、筛选、分页 |
| **健康检查** | ❤️ | 扫描资源库完整性，8 项检查（总大小 / 渲染缓存 / 原始媒体 / 代理媒体 / 优化媒体 / 缺失文件 / 磁盘空间 / 修改时间），按健康 / 警告 / 严重分级 |
| **归档管理** | 📦 | 素材库快速归档，复制到归档目录、生成清单文件、归档历史持久化、一键恢复 |

### 🎨 创作辅助

| 模块 | 图标 | 说明 |
| --- | --- | --- |
| **快速字幕** | 💬 | 基于 macOS Speech 框架的 ASR 语音识别，自动生成 SRT 字幕文件，支持简繁中文 / 英语 / 日语 / 韩语，可导入 / 导出 / 编辑 |
| **输出管理** | 📤 | 管理 FCPX 输出目标（Share Destinations），解析 plist 配置，支持查看 / 复制 / 删除 / 导出，内置 6 种预设模板 |

### ⌨️ 键盘快捷键

| 快捷键 | 功能 |
| --- | --- |
| `⌘1` ~ `⌘8` | 快速切换功能模块 |

## 🖼️ 项目预览

| 模块 | 说明 |
| --- | --- |
| ⚡ 快捷打开 | 一键访问 FCPX 常用目录和启动应用 |
| 📊 进程管理 | 监控 FCPX 运行状态，启动 / 退出 / 强制退出 |
| 🧹 清理助手 | 扫描 `.fcpbundle`、`.fcpproject` 和 FCPX 事件目录，统计可清理缓存 |
| 🧩 模板库 | 浏览 Motion Templates 中的效果、转场、字幕/标题、发生器和合成 |
| ❤️ 健康检查 | 检查资源库完整性，8 项健康指标，分级展示 |
| 📦 归档管理 | 素材库快速归档与恢复，归档历史持久化 |
| 💬 快速字幕 | ASR 语音识别生成 SRT 字幕，支持多语言 |
| 📤 输出管理 | 管理 FCPX 输出目标，预设模板快速创建 |
| 🧪 Electron 原型 | 保留早期 JS/Electron 版本，方便对比和后续迁移 |

## ✅ 当前清理范围

默认安全项：

- `Render Files`
- `Analysis Files`
- `Waveform Cache Files`
- `Thumbnail Media`

需要手动确认：

- `Transcoded Media / High Quality Media`
- `Transcoded Media / Proxy Media`
- `Shared Items`

永不清理：

- `Original Media`

## 🚀 快速开始

### 运行 SwiftUI 原生版

```bash
cd native
swift run
```

### 构建 macOS App

```bash
scripts/generate-icon.py
iconutil -c icns assets/AppIcon.iconset -o assets/AppIcon.icns
scripts/build-native.sh
```

构建后的 App 位于：

```text
dist/native-v0.3/FCPX 工具箱.app
```

### 打包本地安装包

```bash
scripts/package-local.sh
```

输出：

```text
dist/FCPXTools-0.3.0.zip
```

### 运行 Electron 原型

```bash
npm install
npm start
```

> Electron 版本是早期原型，当前主线以 `native/Sources/FCPXToolbox` 为准。

## 🗂️ 目录结构

```text
.
├── assets/                  # App 图标资源
├── native/                  # SwiftUI 原生应用
│   ├── Package.swift
│   └── Sources/FCPXToolbox/
│       ├── App/             # 应用入口、根视图、主题
│       ├── Cleanup/         # 清理助手模块
│       ├── Templates/       # 模板库模块
│       ├── QuickAccess/     # 快捷打开模块
│       ├── ProcessManager/  # 进程管理模块
│       ├── HealthCheck/     # 健康检查模块
│       ├── ArchiveManager/  # 归档管理模块
│       ├── SubtitleTool/    # 快速字幕模块
│       ├── DestinationManager/ # 输出管理模块
│       └── Shared/          # 共享工具（格式化、文件操作）
├── scripts/                 # 图标生成、构建、打包脚本
├── src/                     # Electron 原型
├── package.json             # Electron 原型依赖与打包配置
└── README.md
```

## 🧑‍💻 技术栈

- 🍎 Swift 5.9
- 🖥️ SwiftUI
- 📦 Swift Package Manager
- 🗣️ Speech 框架（ASR 语音识别）
- 🎵 AVFoundation（音频处理）
- ⚙️ Electron 原型
- 🧼 macOS `FileManager.trashItem` 安全移入废纸篓

## ⚠️ 使用提醒

- 建议在清理前关闭 Final Cut Pro，避免资源库正在写入。
- 第一次扫描大体量素材盘时可能需要更久，取决于磁盘速度和文件数量。
- 代理媒体、优化媒体和共享导出文件会影响工作流，请确认后再清理。
- 本项目不会删除 `Original Media`。
- 快速字幕功能需要麦克风 / 语音识别权限。
- 进程管理功能读取内存占用需 macOS 系统权限。

## 🗺️ 项目路线图

| 版本 | 内容 | 状态 |
| --- | --- | --- |
| v0.3.x | 清理助手 + 模板库 | ✅ 已完成 |
| v0.4.0 | 快捷打开 + 进程管理 + 健康检查 + 归档管理 + 快速字幕 + 输出管理 | ✅ 已完成 |
| v0.5 | 深色模式 + 国际化 + 设置模块 + 关于页面 | 🔜 计划中 |
| v0.6 | 欢迎引导 + 快捷键菜单 + 功能增强 | 📋 待定 |
| v0.7 | 性能优化 + 测试覆盖达标 | 📋 待定 |
| v0.8 | 签名 + DMG + 公证 | 📋 待定 |
| v0.9 | Sparkle 自动更新 + 反馈 + 崩溃报告 | 📋 待定 |
| v1.0 | 文档 + 截图 + 最终打磨 | 📋 待定 |

> 完整提升计划请参考 [`.trae/documents/fcpx-toolbox-production-plan.md`](.trae/documents/fcpx-toolbox-production-plan.md)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request。适合贡献的方向包括：

- 扫描规则补充
- UI 体验优化
- 更完整的测试 fixture
- 签名、公证和正式 DMG 分发流程
- 英文界面与多语言支持
- 新功能模块开发

## 📄 开源协议

本项目基于 [MIT License](LICENSE) 开源。
