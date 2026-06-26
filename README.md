# FCPX 工具箱

<p align="center">
  <img src="assets/AppIcon.iconset/icon_512x512@2x.png" width="128" alt="FCPX 工具箱图标">
</p>

<p align="center">
  <strong>为 Final Cut Pro 剪辑师打造的 macOS 原生工具箱。</strong><br>
  10 个功能模块，从快捷打开、清理缓存、模板与插件管理，到健康检查、归档、字幕与输出，一站式覆盖剪辑工作流。
</p>

<p align="center">
  <a href="https://github.com/Gary23333/FCPXTOOLS/releases/tag/v0.4.0"><strong>下载 v0.4.0</strong></a> ·
  <a href="./docs/index.html">产品主页</a> ·
  <a href="#功能模块">功能</a> ·
  <a href="#构建与运行">构建</a>
</p>

<p align="center">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-22C55E?style=flat-square">
  <img alt="Platform" src="https://img.shields.io/badge/macOS-14%2B-0040FF?style=flat-square">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-C5C9C9?style=flat-square">
  <img alt="Version" src="https://img.shields.io/badge/version-0.4.0-F59E0B?style=flat-square">
</p>

---

## 功能模块

| 模块 | 说明 |
| --- | --- |
| **快捷打开** | 一键进入 FCPX 常用目录，直接启动 Final Cut Pro |
| **清理助手** | 扫描 `.fcpbundle` 资源库，按风险分级清理渲染、波形、分析等缓存 |
| **模板库** | 浏览 Motion Templates，按效果、转场、字幕、发生器、合成分类检索 |
| **插件管理** | 集中管理 FCPX / Motion 插件，快速启用、禁用与定位 |
| **色彩管理** | 查看与整理 LUT、色彩预设，辅助统一项目色彩工作流 |
| **快捷键管理** | 浏览、备份与恢复 FCPX 快捷键命令集 |
| **健康检查** | 8 项指标扫描资源库完整性，按健康 / 警告 / 严重分级 |
| **归档管理** | 素材库快速归档、生成清单、持久化历史、一键恢复 |
| **快速字幕** | 基于 macOS Speech 框架的 ASR 语音识别，自动生成 SRT 字幕 |
| **输出管理** | 管理 FCPX 输出目标，查看、复制、删除、导出与预设模板 |

## 下载与安装

1. 从 [GitHub Releases](https://github.com/Gary23333/FCPXTOOLS/releases/tag/v0.4.0) 下载 `FCPXTools-0.4.0.zip`。
2. 解压并将 `FCPX 工具箱.app` 拖入 **应用程序** 文件夹。
3. 首次启动如遇 Gatekeeper 提示，可在 **系统设置 > 隐私与安全性** 中选择“仍要打开”。

> 也可直接查看离线产品主页：[docs/index.html](./docs/index.html)

## 系统要求

- macOS 14 或更高版本
- Swift 5.9
- Final Cut Pro（功能模块按需使用）

## 构建与运行

### 本地运行

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

构建产物位于：

```text
dist/native-v0.4/FCPX 工具箱.app
```

### 打包安装包

```bash
scripts/package-local.sh
```

输出：

```text
dist/FCPXTools-0.4.0.zip
```

## 技术栈

- Swift 5.9
- SwiftUI
- Swift Package Manager
- Speech 框架（语音识别字幕）
- AVFoundation（音频处理）
- macOS `FileManager.trashItem`（安全移入废纸篓）

## 使用提醒

- 清理前建议关闭 Final Cut Pro，避免资源库正在写入。
- 第一次扫描大体量素材盘可能需要更久，取决于磁盘速度和文件数量。
- 代理媒体、优化媒体和共享导出文件会影响工作流，请确认后再清理。
- 本项目**不会删除**原始媒体文件（`Original Media`）。
- 快速字幕功能需要麦克风 / 语音识别权限。

## 贡献

欢迎提交 Issue 和 Pull Request。适合贡献的方向包括：

- 扫描规则与清理策略优化
- UI / 交互体验改进
- 测试覆盖与 fixture 完善
- 签名、公证与正式 DMG 分发流程
- 英文界面与多语言支持
- 新功能模块开发

## 开源协议

本项目基于 [MIT License](LICENSE) 开源。
