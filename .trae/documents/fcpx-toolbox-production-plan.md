# FCPX 工具箱 - 上市级完整项目提升计划

## 一、项目现状分析

### 1.1 当前状态

FCPX 工具箱是一个 macOS 原生应用（SwiftUI），当前版本 v0.3.1，已具备两大核心功能：

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| 🧹 清理助手 | ✅ 可用 | 扫描 FCPX 资源库，按风险分级展示缓存，安全移至废纸篓 |
| 🧩 模板库 | ✅ 可用 | 浏览 Motion Templates，支持分类、搜索、筛选、删除 |
| ⚙️ 偏好设置 | ❌ 缺失 | 无设置界面 |
| 🌍 多语言 | ❌ 缺失 | 仅中文硬编码 |
| 🌙 深色模式 | ⚠️ 部分 | 主题色固定，未适配系统深色模式 |
| 📝 日志系统 | ❌ 缺失 | 无统一日志 |
| 🧪 测试覆盖 | ⚠️ 极低 | 仅 1 个占位测试用例 |
| 📦 分发 | ⚠️ 基础 | 仅 zip 打包，无签名/公证/DMG |
| 🔄 自动更新 | ❌ 缺失 | 无更新机制 |
| 📖 使用引导 | ❌ 缺失 | 无欢迎页/新手引导 |
| ℹ️ 关于页面 | ❌ 缺失 | 无版本信息/许可说明 |

### 1.2 技术栈

- **语言**：Swift 5.9
- **UI 框架**：SwiftUI
- **包管理**：Swift Package Manager
- **平台**：macOS 14+
- **最低部署**：macOS Sonoma 14.0

### 1.3 现有项目结构

```
native/Sources/FCPXToolbox/
├── App/                    # 应用入口与根视图
│   ├── FCPXToolboxApp.swift
│   ├── RootView.swift
│   └── Theme.swift
├── Cleanup/                # 清理模块
│   ├── Scanner.swift
│   ├── Cleaner.swift
│   ├── CleanupModels.swift
│   ├── CleanupView.swift
│   └── CleanupViewModel.swift
├── Templates/              # 模板库模块
│   ├── TemplateScanner.swift
│   ├── TemplateModels.swift
│   ├── TemplateLibraryView.swift
│   ├── TemplateLibraryViewModel.swift
│   ├── TemplateDetailView.swift
│   └── ThumbnailView.swift
└── Shared/                 # 共享工具
    ├── ByteFormatter.swift
    └── FileMover.swift
```

---

## 二、提升目标

将 FCPX 工具箱从 v0.3 的原型级项目提升至可在 Mac App Store / 官网独立分发的 v1.0 正式版，打造 Final Cut Pro 用户的一站式工具箱。核心目标：

1. **产品完整性**：设置、关于、欢迎引导、快捷操作
2. **功能丰富度**：从 2 个模块扩展到 10+ 个实用工具模块
3. **工程质量**：测试覆盖、错误处理、日志系统、架构优化
4. **用户体验**：深色模式、多语言、键盘快捷键、Dock 菜单
5. **分发能力**：签名、公证、DMG、Sparkle 自动更新
6. **性能优化**：扫描速度、内存占用、UI 响应性
7. **商业化准备**：使用统计（隐私优先）、崩溃报告、反馈渠道

---

## 三、功能模块全景

### 3.1 核心工具模块（已有 + 增强）

| 序号 | 模块 | 图标 | 说明 |
| --- | --- | --- | --- |
| 1 | 🧹 清理助手 | sparkles | 扫描清理 FCPX 缓存，释放磁盘空间 |
| 2 | 🧩 模板库 | square.grid.2x2 | 浏览管理 Motion 模板 |
| 3 | 🔌 插件管理器 | puzzlepiece | 管理 FxPlug 插件与效果 |
| 4 | 🎨 色彩管理 | wand.and.stars | LUT、颜色预置管理 |
| 5 | ⌨️ 快捷键管理 | keyboard | FCPX 快捷键预设管理 |
| 6 | 💾 备份助手 | arrow.triangle.2.circlepath | 备份/恢复 FCPX 偏好与模板 |
| 7 | 📊 项目统计 | chart.pie | 资源库详细分析报告 |
| 8 | 🎬 快速启动 | play.circle | 最近项目、快速打开 |
| 9 | 📤 导出预设 | square.and.arrow.up | 导出设置管理与分享 |
| 10 | 🔧 系统诊断 | wrench.and.screwdriver | FCPX 问题诊断与修复 |

### 3.2 产品功能矩阵

```
┌─────────────────────────────────────────────────────────────┐
│                        FCPX 工具箱                           │
├──────────┬──────────┬──────────┬──────────┬──────────┬───────┤
│  清理助手 │  模板库  │ 插件管理 │ 色彩管理 │ 快捷键   │ 备份  │
│  Cleanup  │ Templates│  Plugins │  Color   │ Shortcuts│Backup│
├──────────┼──────────┼──────────┼──────────┼──────────┼───────┤
│  项目统计 │ 快速启动 │ 导出预设 │ 系统诊断 │  设置    │ 关于  │
│  Stats    │ Launcher │  Export  │  Diagnose│ Settings│ About │
└──────────┴──────────┴──────────┴──────────┴──────────┴───────┘
```

---

## 四、详细实施计划

### 阶段 1：工程基础与架构优化

**目标**：打好工程地基，为后续功能扩展铺路。

#### 1.1 项目结构重组

将现有单体模块拆分为更清晰的分层架构，按功能模块组织：

```
native/Sources/FCPXToolbox/
├── App/                          # 应用入口与生命周期
│   ├── FCPXToolboxApp.swift
│   ├── RootView.swift
│   └── AppCommands.swift         # 主菜单命令
├── Core/                         # 核心服务
│   ├── Logging/
│   │   └── AppLogger.swift
│   ├── Persistence/
│   │   └── AppPreferences.swift
│   ├── Errors/
│   │   └── AppError.swift
│   ├── Feedback/
│   │   ├── FeedbackManager.swift
│   │   └── CrashReporter.swift
│   └── Updater/
│       └── AppUpdater.swift
├── Features/                     # 功能模块（每个模块自包含）
│   ├── Cleanup/                  # 已有：清理助手
│   ├── Templates/                # 已有：模板库
│   ├── Plugins/                  # 新增：插件管理器
│   ├── Color/                    # 新增：色彩管理
│   ├── Shortcuts/                # 新增：快捷键管理
│   ├── Backup/                   # 新增：备份助手
│   ├── Stats/                    # 新增：项目统计
│   ├── Launcher/                 # 新增：快速启动
│   ├── ExportPresets/            # 新增：导出预设
│   ├── Diagnostics/              # 新增：系统诊断
│   ├── Settings/                 # 新增：设置
│   ├── About/                    # 新增：关于页面
│   └── Onboarding/               # 新增：欢迎引导
├── UI/                           # 通用 UI 组件
│   ├── Theme/
│   │   └── Theme.swift
│   └── Components/
│       ├── Card.swift
│       ├── EmptyStateView.swift
│       ├── ProgressBar.swift
│       └── SectionHeader.swift
├── Utils/                        # 工具类
│   ├── FileMover.swift
│   ├── ByteFormatter.swift
│   └── FCPXPaths.swift           # FCPX 相关路径常量
└── Resources/                    # 资源文件
    ├── en.lproj/
    │   └── Localizable.strings
    └── zh-Hans.lproj/
        └── Localizable.strings
```

#### 1.2 统一日志系统

- 新增 `AppLogger` 类，基于 `OSLog` 框架
- 分级：debug / info / warning / error / fault
- 支持文件输出，便于用户提交诊断
- 所有现有错误路径接入日志

#### 1.3 用户偏好存储

- 基于 `UserDefaults` 封装 `AppPreferences`
- 支持默认扫描路径、风险确认级别、界面语言等
- 后续设置页面直接消费

#### 1.4 错误类型标准化

- 定义统一的 `FCPXToolboxError` 枚举
- 所有 throwing 函数使用统一错误类型
- 提供用户友好的错误描述

#### 1.5 FCPX 路径常量

- 集中管理 FCPX 相关路径：
  - 用户模板目录：`~/Movies/Motion Templates.localized/`
  - 系统模板目录：`/Library/Application Support/Final Cut Pro/Templates/`
  - 插件目录：`~/Library/Plug-Ins/FxPlug/`
  - 偏好设置：`~/Library/Preferences/com.apple.FinalCut.plist`
  - 快捷键预设：`~/Library/Application Support/Final Cut Pro/Command Sets/`
  - 颜色预置：`~/Library/Application Support/ProApps/Color Presets/`
  - LUT 目录：`~/Library/Application Support/ProApps/Custom LUTs/`
  - 导出预设：`~/Library/Application Support/ProApps/Export Settings/`

**新增文件**：
- `native/Sources/FCPXToolbox/Utils/FCPXPaths.swift`

---

### 阶段 2：测试覆盖与质量保障

**目标**：核心逻辑有测试保护，敢放心迭代。

#### 2.1 扫描逻辑测试

为 `FCPXScanner` 编写单元测试：

- 空目录扫描
- 单个 fcpbundle 识别
- 嵌套资源库正确分组
- 各缓存类型正确归类
- 取消扫描功能
- 权限错误处理
- 符号链接跳过

#### 2.2 清理逻辑测试

为 `FCPXCleanerCore` 编写单元测试：

- 成功清理计数
- 失败项收集
- 清理进度回调
- 空目标数组处理

#### 2.3 视图模型测试

为 `CleanupViewModel` / `TemplateLibraryViewModel` 编写测试：

- 选择状态切换
- 统计数据计算
- 分页逻辑
- 过滤与搜索

#### 2.4 模板扫描测试

为 `TemplateScanner` 编写测试：

- 各分类正确识别
- .localized 显示名解析
- 大小/时间测量准确性
- 用户/系统目录区分

#### 2.5 新增模块测试

- 插件扫描测试
- 备份/恢复逻辑测试
- 偏好读取/写入测试
- 路径工具测试

#### 2.6 测试文件结构

```
native/Tests/FCPXToolboxTests/
├── ScannerTests.swift
├── CleanerTests.swift
├── CleanupViewModelTests.swift
├── TemplateScannerTests.swift
├── TemplateLibraryViewModelTests.swift
├── PluginScannerTests.swift
├── BackupManagerTests.swift
├── PreferencesTests.swift
├── FormattingTests.swift
├── PathUtilsTests.swift
└── Fixtures/                     # 测试用模拟目录结构
    ├── SampleLibrary.fcpbundle/
    ├── SampleTemplates/
    ├── SamplePlugins/
    └── SamplePreferences/
```

**测试目标**：核心逻辑覆盖率 ≥ 70%

---

### 阶段 3：主题系统与深色模式

**目标**：完美适配 macOS 明暗主题，界面更专业。

#### 3.1 主题系统重构

- 将 `Theme.swift` 从静态颜色改为响应系统外观的动态颜色
- 使用语义色（background、secondaryBackground、tertiaryBackground 等）
- 定义完整的 Design Token 体系

#### 3.2 适配项

| 组件 | 改动 |
| --- | --- |
| 背景色 | 支持动态切换（三级背景体系） |
| 面板色 | 支持动态切换 |
| 文字色 | primary / secondary / tertiary |
| 边框/分割线 | 支持动态切换 |
| 强调色 | 沿用品牌绿，深浅模式微调 |
| 图标 | SF Symbols 天然适配 |

#### 3.3 新增设置项

- 外观设置：跟随系统 / 浅色 / 深色

---

### 阶段 4：国际化（i18n）

**目标**：支持中英文双语，为更多语言扩展铺路。

#### 4.1 字符串本地化

- 所有硬编码中文字符串提取到 `Localizable.strings`
- 英文翻译
- 使用 `String(localized:comment:)` 或 `NSLocalizedString`

#### 4.2 界面适配

- 确保布局在中英文下都不截断
- 数字/日期格式跟随系统 locale

#### 4.3 语言设置

- 设置中增加语言选择：跟随系统 / 简体中文 / English
- 启动时或设置变更时动态切换（SwiftUI 环境变量）

#### 4.4 资源文件

- `Info.plist` 本地化
- 帮助文档本地化

---

### 阶段 5：新增功能模块 - 插件管理器

**目标**：让用户方便地管理 FCPX 插件。

#### 5.1 功能说明

- 扫描用户和系统插件目录
- 按类型分类：FxPlug、效果、转场、字幕、发生器
- 显示插件信息：名称、厂商、版本、大小、安装位置
- 启用/禁用插件（通过移动到 Disabled 文件夹）
- 插件卸载（移至废纸篓）
- 搜索与筛选
- 插件冲突检测（同名插件）

#### 5.2 实现文件

```
native/Sources/FCPXToolbox/Features/Plugins/
├── PluginScanner.swift
├── PluginModels.swift
├── PluginManagerView.swift
├── PluginManagerViewModel.swift
└── PluginDetailView.swift
```

#### 5.3 插件数据模型

```swift
struct PluginItem: Identifiable {
    let id: URL
    let name: String
    let displayName: String
    let type: PluginType       // fxPlug / effect / transition / title / generator
    let vendor: String
    let version: String?
    let sizeBytes: Int64
    let modifiedAt: Date?
    let location: PluginLocation  // user / system
    let isEnabled: Bool
}
```

---

### 阶段 6：新增功能模块 - 色彩管理

**目标**：集中管理 LUT 和颜色预置。

#### 6.1 功能说明

- LUT 管理：
  - 扫描自定义 LUT 目录
  - 支持 .cube / .mga / .m3d 等格式
  - LUT 预览（对测试图像应用效果）
  - 导入/导出 LUT
  - 分类整理

- 颜色预置管理：
  - 扫描 FCPX 颜色预置目录
  - 预置预览与比较
  - 备份与恢复
  - 导入第三方预置

#### 6.2 实现文件

```
native/Sources/FCPXToolbox/Features/Color/
├── ColorScanner.swift
├── ColorModels.swift
├── ColorManagerView.swift
├── ColorManagerViewModel.swift
├── LUTDetailView.swift
└── LUTPreviewView.swift
```

---

### 阶段 7：新增功能模块 - 快捷键管理

**目标**：方便地管理 FCPX 快捷键预设。

#### 7.1 功能说明

- 扫描 FCPX 快捷键预设目录
- 显示所有可用快捷键集
- 预设切换（设置为当前使用）
- 导入/导出快捷键预设
- 快捷键可视化（按键图）
- 预设对比（两个预设的差异）
- 备份与恢复

#### 7.2 实现文件

```
native/Sources/FCPXToolbox/Features/Shortcuts/
├── ShortcutScanner.swift
├── ShortcutModels.swift
├── ShortcutManagerView.swift
├── ShortcutManagerViewModel.swift
├── ShortcutDetailView.swift
└── KeyboardView.swift
```

---

### 阶段 8：新增功能模块 - 备份助手

**目标**：一键备份/恢复 FCPX 配置，换机无忧。

#### 8.1 功能说明

- 可备份项：
  - FCPX 偏好设置
  - Motion 模板（用户目录）
  - 快捷键预设
  - 颜色预置 & LUT
  - 导出预设
  - 插件列表（仅清单，不备份插件本体）
  - 用户自定义效果/转场

- 备份操作：
  - 选择要备份的项目
  - 打包为 .fcpxbackup 文件
  - 显示备份大小和时间
  - 自动版本号

- 恢复操作：
  - 选择备份文件
  - 预览备份内容
  - 选择要恢复的项目
  - 冲突处理（覆盖/跳过/重命名）

#### 8.2 实现文件

```
native/Sources/FCPXToolbox/Features/Backup/
├── BackupManager.swift
├── BackupModels.swift
├── BackupView.swift
├── BackupViewModel.swift
├── RestoreView.swift
└── BackupDetailView.swift
```

---

### 阶段 9：新增功能模块 - 项目统计

**目标**：深入分析资源库，可视化展示数据。

#### 9.1 功能说明

- 资源库总览：
  - 总占用空间
  - 原始素材占比
  - 缓存占比
  - 代理/优化媒体占比

- 详细分析：
  - 按事件统计
  - 按项目统计
  - 文件类型分布
  - 媒体时长估算
  - 修改时间分布

- 可视化图表：
  - 空间占用饼图
  - 事件大小柱状图
  - 时间趋势图

- 报告导出：
  - PDF 报告
  - CSV 数据导出
  - 分享功能

#### 9.2 实现文件

```
native/Sources/FCPXToolbox/Features/Stats/
├── StatsScanner.swift
├── StatsModels.swift
├── StatsView.swift
├── StatsViewModel.swift
├── StatsDetailView.swift
└── Charts/
    ├── PieChartView.swift
    ├── BarChartView.swift
    └── ChartModels.swift
```

---

### 阶段 10：新增功能模块 - 快速启动

**目标**：快速访问最近项目，一键打开。

#### 10.1 功能说明

- 最近项目列表：
  - 自动扫描最近打开的 FCPX 项目
  - 从 FCPX 偏好中读取最近项目
  - 手动添加项目到收藏

- 快速操作：
  - 一键打开项目
  - 在 Finder 中显示
  - 固定常用项目
  - 搜索项目

- 项目信息：
  - 项目名称
  - 最后打开时间
  - 项目大小
  - 资源库位置

#### 10.2 实现文件

```
native/Sources/FCPXToolbox/Features/Launcher/
├── RecentProjectsScanner.swift
├── LauncherModels.swift
├── LauncherView.swift
└── LauncherViewModel.swift
```

---

### 阶段 11：新增功能模块 - 导出预设

**目标**：管理和分享 FCPX 导出设置。

#### 11.1 功能说明

- 扫描 FCPX 导出预设目录
- 按类型分类：视频、音频、图像、序列帧等
- 预设详情：分辨率、码率、编码、格式
- 预设导入/导出
- 预设备份
- 批量导出预设包

#### 11.2 实现文件

```
native/Sources/FCPXToolbox/Features/ExportPresets/
├── ExportPresetScanner.swift
├── ExportPresetModels.swift
├── ExportPresetsView.swift
└── ExportPresetsViewModel.swift
```

---

### 阶段 12：新增功能模块 - 系统诊断

**目标**：自动检测 FCPX 常见问题，提供修复建议。

#### 12.1 功能说明

- 诊断项目：
  - FCPX 版本兼容性
  - 插件冲突检测
  - 缓存异常
  - 偏好设置损坏
  - 磁盘空间不足
  - 权限问题（完全磁盘访问）
  - 系统版本兼容性
  - 渲染文件损坏

- 诊断报告：
  - 问题等级（严重/警告/提示）
  - 问题描述
  - 修复建议
  - 一键修复（部分问题）

- 诊断历史：
  - 保存诊断记录
  - 对比前后变化

#### 12.2 实现文件

```
native/Sources/FCPXToolbox/Features/Diagnostics/
├── DiagnosticEngine.swift
├── DiagnosticModels.swift
├── DiagnosticsView.swift
├── DiagnosticsViewModel.swift
├── DiagnosticDetailView.swift
└── FixActions.swift
```

---

### 阶段 13：设置与关于模块

**目标**：用户可自定义应用行为，体现产品完整度。

#### 13.1 设置界面

使用 SwiftUI `Settings` 场景，分 Tab 展示：

| Tab | 内容 |
| --- | --- |
| 通用 | 默认扫描目录、清理确认方式、自动检查更新、启动行为 |
| 外观 | 主题、语言、窗口默认大小、侧边栏图标大小 |
| 功能 | 各功能模块启用/禁用、默认启动页 |
| 高级 | 日志级别、废纸篓保留提醒、磁盘空间阈值警告 |
| 关于 | 版本、版权、许可、官网链接 |

#### 13.2 新增偏好项

- `defaultSection: ToolSection` — 默认启动模块
- `defaultScanPath: URL?` — 默认扫描目录
- `confirmBeforeClean: Bool` — 清理前二次确认
- `autoCheckUpdates: Bool` — 自动检查更新
- `appearance: AppearanceMode` — 外观模式
- `language: LanguageOption` — 语言
- `logLevel: LogLevel` — 日志级别
- `warnWhenFreeSpaceBelowGB: Double` — 磁盘空间警告阈值
- `enabledSections: Set<ToolSection>` — 启用的功能模块

---

### 阶段 14：关于页面与欢迎引导

**目标**：给用户一个完整的「第一印象」和「产品身份」。

#### 14.1 关于页面

- App 图标 + 名称 + 版本号 + 构建号
- 一句话产品描述
- 版权声明
- 开源许可列表
- 官网 / 反馈 / 隐私政策链接
- 「检查更新」按钮
- 致谢名单

#### 14.2 欢迎引导（Onboarding）

首次启动或大版本升级时展示：

- 第 1 屏：产品介绍 + 核心功能亮点（10 个模块图标）
- 第 2 屏：安全说明（只移废纸篓、不碰原始素材、数据不出本地）
- 第 3 屏：权限引导（完全磁盘访问权限说明 + 授权按钮）
- 第 4 屏：功能选择（用户可选择启用哪些模块）
- 第 5 屏：快速开始按钮

---

### 阶段 15：键盘快捷键与菜单

**目标**：专业 macOS 应用的标配，提升效率用户体验。

#### 15.1 主菜单

完善 `CommandGroup` 和菜单项：

| 菜单 | 菜单项 | 快捷键 |
| --- | --- | --- |
| FCPX 工具箱 | 关于… | — |
| | 偏好设置… | ⌘, |
| | 检查更新… | — |
| | 退出 | ⌘Q |
| 文件 | 选择扫描目录… | ⌘O |
| | 重新扫描 | ⌘R |
| | 停止扫描 | ⌘. |
| | 在 Finder 显示 | ⌘⇧F |
| | 新建备份 | ⌘N |
| 编辑 | 全选安全项 | ⌘A |
| | 取消全选 | ⌘⇧A |
| 视图 | 切换模块 | ⌘1 ~ ⌘0 |
| | 放大/缩小/实际大小 | ⌘+ / ⌘- / ⌘0 |
| | 切换侧边栏 | ⌃⌘S |
| 工具 | 开始诊断 | ⌘D |
| | 快速备份 | ⌘B |
| 清理 | 清理所选 | ⌘⌫ |
| 窗口 | 最小化 | ⌘M |
| | 缩放 | ⌥⌘M |
| 帮助 | FCPX 工具箱帮助 | ⌘? |
| | 提交反馈 | — |

#### 15.2 Dock 菜单

- 快速扫描最近目录
- 新建清理窗口
- 快速备份
- 最近项目列表（快速启动）

---

### 阶段 16：分发与自动更新

**目标**：用户能顺畅地下载、安装、更新。

#### 16.1 构建脚本增强

完善 `scripts/build-native.sh`：

- 支持 Release 构建
- 支持 Universal Binary（Apple Silicon + Intel）
- 自动读取版本号
- 产物命名规范
- 支持不同分发渠道（MAS / 独立版）

#### 16.2 代码签名与公证

- 签名配置：Developer ID 证书
- 构建后自动签名
- 自动提交苹果公证
- 公证结果检查与 stapling
- 公证脚本封装

#### 16.3 DMG 安装包

- 使用 `create-dmg` 生成专业 DMG
- 背景图、应用程序文件夹快捷方式、正确的窗口大小
- 签名 DMG
- 支持暗黑模式背景图

#### 16.4 Sparkle 自动更新

- 集成 Sparkle 2.x
- 配置 Appcast feed
- 设置中加入「自动检查更新」开关
- 关于页面加入「检查更新」按钮
- 支持自动下载和手动下载

#### 16.5 版本管理

- `VERSION` 文件统一管理版本号
- `CHANGELOG.md` 记录每次更新
- 构建脚本自动读取版本并注入 Info.plist
- 支持 Build Number 自动递增

---

### 阶段 17：性能优化

**目标**：大体量素材盘也能流畅使用。

#### 17.1 扫描性能

- 并发目录遍历（`FileManager.enumerator` 优化）
- 文件大小测量并发化（TaskGroup）
- 按目录深度优先级队列
- 符号链接快速跳过
- 扫描结果增量更新 UI

#### 17.2 内存优化

- 大量文件时避免一次性加载所有 URL
- 列表虚拟化 / 分页加载（现有基础上优化）
- 缩略图缓存池，及时释放非可见区域资源
- 大图按需加载

#### 17.3 UI 响应性

- 所有磁盘操作严格在后台队列
- 进度更新节流（已有基础，进一步优化）
- 大列表用 `LazyVStack` / `LazyVGrid`
- 模块按需加载，启动时只加载首屏

#### 17.4 启动速度优化

- 延迟加载非首屏模块
- 并行初始化核心服务
- 缓存最近扫描结果

#### 17.5 性能基准测试

- 建立基准测试套件
- 对 1000+ 模板、100+ 资源库的场景做性能测试
- 插件扫描性能测试

---

### 阶段 18：反馈与崩溃报告

**目标**：上线后能快速发现和定位问题。

#### 18.1 崩溃报告

- 可选：集成 `PLCrashReporter` 或直接用 `ReportCrash`
- 用户可选择是否发送
- 崩溃报告附带基本系统信息（macOS 版本、机型、App 版本）
- 崩溃报告匿名化处理

#### 18.2 反馈功能

- 内置反馈表单：问题类型、描述、联系方式
- 可附加日志文件
- 可附加系统信息（可选）
- 发送到指定邮箱或 API（可配置）

#### 18.3 隐私设计

- 所有数据收集默认关闭
- 首次启动明确询问
- 设置中可随时开关
- 符合 GDPR / 国内隐私法规
- 透明的数据使用说明

---

### 阶段 19：文档与资源

**目标**：专业产品该有的物料。

#### 19.1 用户手册

- 快速入门指南
- 功能详解（每个模块单独章节）
- 常见问题 FAQ
- 故障排查
- 快捷键速查表

#### 19.2 应用截图

- 清理模块截图
- 模板库截图
- 插件管理器截图
- 色彩管理截图
- 快捷键管理截图
- 备份助手截图
- 设置界面截图
- 深色模式截图
- 欢迎引导截图

#### 19.3 官网落地页（可选）

- 产品介绍
- 功能亮点（10 个模块逐一展示）
- 下载按钮
- 定价（如收费）
- 用户评价
- 博客/更新日志

---

## 五、文件变更清单

### 5.1 新增文件（核心）

```
native/Sources/FCPXToolbox/
├── App/
│   └── AppCommands.swift
├── Core/
│   ├── Logging/
│   │   └── AppLogger.swift
│   ├── Persistence/
│   │   └── AppPreferences.swift
│   ├── Errors/
│   │   └── AppError.swift
│   ├── Feedback/
│   │   ├── FeedbackManager.swift
│   │   └── CrashReporter.swift
│   └── Updater/
│       └── AppUpdater.swift
├── Features/
│   ├── Plugins/
│   │   ├── PluginScanner.swift
│   │   ├── PluginModels.swift
│   │   ├── PluginManagerView.swift
│   │   ├── PluginManagerViewModel.swift
│   │   └── PluginDetailView.swift
│   ├── Color/
│   │   ├── ColorScanner.swift
│   │   ├── ColorModels.swift
│   │   ├── ColorManagerView.swift
│   │   ├── ColorManagerViewModel.swift
│   │   ├── LUTDetailView.swift
│   │   └── LUTPreviewView.swift
│   ├── Shortcuts/
│   │   ├── ShortcutScanner.swift
│   │   ├── ShortcutModels.swift
│   │   ├── ShortcutManagerView.swift
│   │   ├── ShortcutManagerViewModel.swift
│   │   ├── ShortcutDetailView.swift
│   │   └── KeyboardView.swift
│   ├── Backup/
│   │   ├── BackupManager.swift
│   │   ├── BackupModels.swift
│   │   ├── BackupView.swift
│   │   ├── BackupViewModel.swift
│   │   ├── RestoreView.swift
│   │   └── BackupDetailView.swift
│   ├── Stats/
│   │   ├── StatsScanner.swift
│   │   ├── StatsModels.swift
│   │   ├── StatsView.swift
│   │   ├── StatsViewModel.swift
│   │   ├── StatsDetailView.swift
│   │   └── Charts/
│   │       ├── PieChartView.swift
│   │       ├── BarChartView.swift
│   │       └── ChartModels.swift
│   ├── Launcher/
│   │   ├── RecentProjectsScanner.swift
│   │   ├── LauncherModels.swift
│   │   ├── LauncherView.swift
│   │   └── LauncherViewModel.swift
│   ├── ExportPresets/
│   │   ├── ExportPresetScanner.swift
│   │   ├── ExportPresetModels.swift
│   │   ├── ExportPresetsView.swift
│   │   └── ExportPresetsViewModel.swift
│   ├── Diagnostics/
│   │   ├── DiagnosticEngine.swift
│   │   ├── DiagnosticModels.swift
│   │   ├── DiagnosticsView.swift
│   │   ├── DiagnosticsViewModel.swift
│   │   ├── DiagnosticDetailView.swift
│   │   └── FixActions.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── SettingsViewModel.swift
│   ├── About/
│   │   └── AboutView.swift
│   └── Onboarding/
│       ├── OnboardingView.swift
│       └── OnboardingViewModel.swift
├── UI/
│   ├── Theme/
│   │   └── Theme.swift
│   └── Components/
│       ├── Card.swift
│       ├── EmptyStateView.swift
│       ├── ProgressBar.swift
│       └── SectionHeader.swift
├── Utils/
│   └── FCPXPaths.swift
└── Resources/
    ├── en.lproj/
    │   └── Localizable.strings
    └── zh-Hans.lproj/
        └── Localizable.strings

native/Tests/FCPXToolboxTests/
├── ScannerTests.swift
├── CleanerTests.swift
├── CleanupViewModelTests.swift
├── TemplateScannerTests.swift
├── TemplateLibraryViewModelTests.swift
├── PluginScannerTests.swift
├── BackupManagerTests.swift
├── PreferencesTests.swift
├── FormattingTests.swift
├── PathUtilsTests.swift
└── Fixtures/
    ├── SampleLibrary.fcpbundle/
    ├── SampleTemplates/
    ├── SamplePlugins/
    └── SamplePreferences/

scripts/
├── notarize.sh
├── create-dmg.sh
└── release.sh
```

### 5.2 修改文件

| 文件 | 改动说明 |
| --- | --- |
| `FCPXToolboxApp.swift` | 添加 Settings 场景、菜单、生命周期事件、模块注册 |
| `RootView.swift` | 增加侧边栏 10 个模块、接入欢迎引导、适配新主题 |
| `Theme.swift` | 重构为动态主题系统，支持深色模式 |
| `CleanupView.swift` | 字符串本地化、右键菜单、快捷键、功能增强 |
| `CleanupViewModel.swift` | 接入偏好存储、历史记录、日志 |
| `Scanner.swift` | 错误标准化、日志、性能优化 |
| `Cleaner.swift` | 错误标准化、日志 |
| `TemplateLibraryView.swift` | 本地化、右键菜单、功能增强 |
| `TemplateLibraryViewModel.swift` | 接入偏好、日志 |
| `Package.swift` | 添加 Sparkle 等依赖、资源文件、测试 target |
| `build-native.sh` | 增强 Release 构建、签名、版本注入 |
| `README.md` | 更新功能列表、安装说明、截图 |

---

## 六、依赖新增

| 依赖 | 用途 | 可选 |
| --- | --- | --- |
| Sparkle 2.x | 自动更新 | 是（独立分发需要） |
| XCTest 已有 | 单元测试 | 否 |
| OSLog 系统框架 | 日志 | 否（系统内置） |
| Swift Charts（系统） | 统计图表 | 否（系统内置，macOS 14+） |

> 注：尽可能使用系统原生框架，减少第三方依赖，保证 App 体积小、启动快。

---

## 七、风险与应对

| 风险 | 影响 | 应对策略 |
| --- | --- | --- |
| 签名与公证需要 Apple Developer 账号 | 无法正式分发 | 先完成功能开发，签名步骤在拿到证书后执行 |
| 深色模式适配工作量大 | UI 细节问题多 | 先完成动态颜色系统，再逐个模块验证 |
| 本地化字符串遗漏 | 部分界面仍为中文 | 建立本地化 checklist，逐屏检查 |
| 测试用 fixture 构建复杂 | 测试开发慢 | 先做核心逻辑测试，fixture 逐步丰富 |
| Sparkle 集成复杂 | 自动更新不可靠 | 先手动发布，后续再加上自动更新 |
| 新功能模块太多导致工期长 | 交付延期 | 按优先级分阶段交付，MVP 先上核心 5 个模块 |
| FCPX 私有 API 可能变动 | 部分功能失效 | 关键功能有 fallback，只读操作优先 |
| 插件管理功能复杂 | 兼容性问题多 | 先做扫描和列表，启用/禁用功能逐步完善 |

---

## 八、发布里程碑

| 版本 | 内容 | 目标 | 功能模块数 |
| --- | --- | --- | --- |
| v0.4 | 工程基础 + 测试 + 日志 + 错误处理 | 内部质量达标 | 2（原有） |
| v0.5 | 深色模式 + 国际化 + 设置 + 关于 | 产品完整性 | 2 + 基础 |
| v0.6 | 欢迎引导 + 快捷键 + 菜单 | 用户体验完善 | 2 + 基础 |
| v0.7 | 插件管理器 + 色彩管理 | 新增 2 个模块 | 4 |
| v0.8 | 快捷键管理 + 备份助手 | 新增 2 个模块 | 6 |
| v0.9 | 项目统计 + 快速启动 | 新增 2 个模块 | 8 |
| v0.10 | 导出预设 + 系统诊断 | 新增 2 个模块 | 10 |
| v0.11 | 性能优化 + 测试覆盖达标 | 大体量场景流畅 | 10 |
| v0.12 | 签名 + DMG + 公证 | 可独立分发 | 10 |
| v0.13 | Sparkle 自动更新 + 反馈 + 崩溃报告 | 可持续迭代 | 10 |
| v1.0 | 文档 + 截图 + 最终打磨 | 正式发布 | 10 |

---

## 九、验证标准

每个阶段完成后，需满足以下验证标准：

1. **功能验证**：新功能按设计正常工作
2. **构建验证**：Release 构建无警告、无错误
3. **测试验证**：新增代码有对应测试，核心逻辑覆盖达标
4. **UI 验证**：深浅模式下无显示问题
5. **本地化验证**：中英文切换无遗漏
6. **性能验证**：扫描/清理性能不退化
7. **内存验证**：无内存泄漏（Instrument 检查）
8. **安全验证**：所有文件操作都在用户授权范围内

---

*计划版本：v2.0（已扩展功能模块）*
*更新日期：2026-06-24*
