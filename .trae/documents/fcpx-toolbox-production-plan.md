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

将 FCPX 工具箱从 v0.3 的原型级项目提升至可在 Mac App Store / 官网独立分发的 v1.0 正式版，涵盖：

1. **产品完整性**：设置、关于、欢迎引导、快捷操作
2. **工程质量**：测试覆盖、错误处理、日志系统、架构优化
3. **用户体验**：深色模式、多语言、键盘快捷键、Dock 菜单
4. **分发能力**：签名、公证、DMG、Sparkle 自动更新
5. **性能优化**：扫描速度、内存占用、UI 响应性
6. **商业化准备**：使用统计（隐私优先）、崩溃报告、反馈渠道

---

## 三、详细实施计划

### 阶段 1：工程基础与架构优化

**目标**：打好工程地基，为后续功能扩展铺路。

#### 1.1 项目结构重组

将现有单体模块拆分为更清晰的分层架构，新增：

```
native/Sources/FCPXToolbox/
├── App/                    # 应用入口与生命周期
├── Features/               # 功能模块（按特性组织）
│   ├── Cleanup/
│   ├── Templates/
│   ├── Settings/           # 新增：设置模块
│   ├── About/              # 新增：关于页面
│   └── Onboarding/         # 新增：欢迎引导
├── Core/                   # 核心服务（新增）
│   ├── Logging/            # 日志系统
│   ├── Persistence/        # 用户偏好存储
│   ├── Feedback/           # 反馈与崩溃报告
│   └── Updater/            # 自动更新（Sparkle）
├── UI/                     # 通用 UI 组件（新增）
│   ├── Components/         # 可复用组件
│   └── Theme/              # 主题系统（支持深色模式）
└── Utils/                  # 工具类
```

#### 1.2 统一日志系统

- 新增 `AppLogger` 类，基于 `OSLog` 框架
- 分级：debug / info / warning / error / fault
- 支持文件输出，便于用户提交诊断
- 所有现有错误路径接入日志

**新增文件**：
- `native/Sources/FCPXToolbox/Core/Logging/AppLogger.swift`

#### 1.3 用户偏好存储

- 基于 `UserDefaults` 封装 `AppPreferences`
- 支持默认扫描路径、风险确认级别、界面语言等
- 后续设置页面直接消费

**新增文件**：
- `native/Sources/FCPXToolbox/Core/Persistence/AppPreferences.swift`

#### 1.4 错误类型标准化

- 定义统一的 `FCPXToolboxError` 枚举
- 所有 throwing 函数使用统一错误类型
- 提供用户友好的错误描述

**新增文件**：
- `native/Sources/FCPXToolbox/Core/Errors/AppError.swift`

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

#### 2.5 UI 组件快照测试（可选）

使用快照测试验证关键界面渲染。

**测试文件结构**：

```
native/Tests/FCPXToolboxTests/
├── ScannerTests.swift
├── CleanerTests.swift
├── CleanupViewModelTests.swift
├── TemplateScannerTests.swift
├── TemplateLibraryViewModelTests.swift
├── FormattingTests.swift
└── Fixtures/                 # 测试用模拟目录结构
    ├── SampleLibrary.fcpbundle/
    └── SampleTemplates/
```

**测试目标**：核心逻辑覆盖率 ≥ 70%

---

### 阶段 3：主题系统与深色模式

**目标**：完美适配 macOS 明暗主题，界面更专业。

#### 3.1 主题系统重构

- 将 `Theme.swift` 从静态颜色改为响应系统外观的动态颜色
- 使用 `Color` 的 `init(name:bundle:)` 或语义色
- 定义完整的 Design Token 体系

#### 3.2 适配项

| 组件 | 改动 |
| --- | --- |
| 背景色 | 支持动态切换 |
| 面板色 | 支持动态切换 |
| 文字色 | 支持动态切换 |
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

**新增文件**：
- `native/Sources/FCPXToolbox/Resources/en.lproj/Localizable.strings`
- `native/Sources/FCPXToolbox/Resources/zh-Hans.lproj/Localizable.strings`

---

### 阶段 5：设置与偏好模块

**目标**：用户可自定义应用行为，体现产品完整度。

#### 5.1 设置界面

使用 SwiftUI `Settings` 场景，分 Tab 展示：

| Tab | 内容 |
| --- | --- |
| 通用 | 默认扫描目录、清理确认方式、自动检查更新 |
| 外观 | 主题、语言、窗口默认大小 |
| 高级 | 日志级别、废纸篓保留提醒、磁盘空间阈值警告 |
| 关于 | 版本、版权、许可、官网链接 |

#### 5.2 新增偏好项

- `defaultScanPath: URL?` — 默认扫描目录
- `confirmBeforeClean: Bool` — 清理前二次确认
- `autoCheckUpdates: Bool` — 自动检查更新
- `appearance: AppearanceMode` — 外观模式
- `language: LanguageOption` — 语言
- `logLevel: LogLevel` — 日志级别
- `warnWhenFreeSpaceBelowGB: Double` — 磁盘空间警告阈值

#### 5.3 实现文件

- `native/Sources/FCPXToolbox/Features/Settings/SettingsView.swift`
- `native/Sources/FCPXToolbox/Features/Settings/SettingsViewModel.swift`

---

### 阶段 6：关于页面与欢迎引导

**目标**：给用户一个完整的「第一印象」和「产品身份」。

#### 6.1 关于页面

- App 图标 + 名称 + 版本号 + 构建号
- 版权声明
- 开源许可列表
- 官网 / 反馈 / 隐私政策链接
- 「检查更新」按钮

#### 6.2 欢迎引导（Onboarding）

首次启动或大版本升级时展示：

- 第 1 屏：产品介绍 + 核心功能亮点
- 第 2 屏：安全说明（只移废纸篓、不碰原始素材）
- 第 3 屏：权限引导（完全磁盘访问权限说明）
- 第 4 屏：快速开始按钮

#### 6.3 实现文件

- `native/Sources/FCPXToolbox/Features/About/AboutView.swift`
- `native/Sources/FCPXToolbox/Features/Onboarding/OnboardingView.swift`
- `native/Sources/FCPXToolbox/Features/Onboarding/OnboardingViewModel.swift`

---

### 阶段 7：键盘快捷键与菜单

**目标**：专业 macOS 应用的标配，提升效率用户体验。

#### 7.1 主菜单

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
| 编辑 | 全选安全项 | ⌘A |
| | 取消全选 | ⌘⇧A |
| 视图 | 切换清理/模板库 | ⌘1 / ⌘2 |
| | 放大/缩小/实际大小 | ⌘+ / ⌘- / ⌘0 |
| 清理 | 清理所选 | ⌘⌫ |
| 帮助 | FCPX 工具箱帮助 | ⌘? |

#### 7.2 Dock 菜单

- 快速扫描最近目录
- 新建清理窗口

---

### 阶段 8：功能增强

**目标**：让现有功能更强大、更贴心。

#### 8.1 清理模块增强

| 功能 | 说明 |
| --- | --- |
| 扫描历史 | 保存最近扫描的目录，一键重扫 |
| 清理历史 | 记录每次清理的时间、释放空间、项目数 |
| 定时清理 | 可选：每周/每月自动清理安全缓存 |
| 磁盘空间仪表盘 | 在状态栏显示可清理空间总览 |
| 导出报告 | 导出扫描/清理结果为 CSV 或 JSON |
| 批量操作 | 右键菜单：批量勾选/取消/在 Finder 显示 |

#### 8.2 模板库增强

| 功能 | 说明 |
| --- | --- |
| 模板预览 | 预览模板效果（如果有 preview.png） |
| 收藏夹 | 标记常用模板 |
| 模板重命名 | 用户模板支持重命名 |
| 导入/导出 | 备份用户模板列表 |
| 模板安装 | 拖拽 .zip / .dmg 模板包自动安装 |

#### 8.3 新增功能模块（可选，视产品定位）

| 模块 | 说明 |
| --- | --- |
| 🎨 色彩配置管理 | 管理 FCPX 颜色预置、LUT |
| 📊 项目统计 | 资源库详细统计报告、可视化图表 |
| 💾 备份助手 | 一键备份 FCPX 偏好设置和模板 |

---

### 阶段 9：分发与自动更新

**目标**：用户能顺畅地下载、安装、更新。

#### 9.1 构建脚本增强

完善 `scripts/build-native.sh`：

- 支持 Release 构建
- 支持 Universal Binary（Apple Silicon + Intel）
- 自动读取版本号
- 产物命名规范

#### 9.2 代码签名与公证

- 签名配置：Developer ID 证书
- 构建后自动签名
- 自动提交苹果公证
- 公证结果检查与 stapling

#### 9.3 DMG 安装包

- 使用 `create-dmg` 或 `dmgbuild` 生成专业 DMG
- 背景图、应用程序文件夹快捷方式、正确的窗口大小
- 签名 DMG

#### 9.4 Sparkle 自动更新

- 集成 Sparkle 2.x
- 配置 Appcast feed
- 设置中加入「自动检查更新」开关
- 关于页面加入「检查更新」按钮

#### 9.5 版本管理

- `VERSION` 文件统一管理版本号
- `CHANGELOG.md` 记录每次更新
- 构建脚本自动读取版本并注入 Info.plist

---

### 阶段 10：性能优化

**目标**：大体量素材盘也能流畅使用。

#### 10.1 扫描性能

- 并发目录遍历（`FileManager.enumerator` 优化）
- 文件大小测量并发化（OperationQueue / TaskGroup）
- 按目录深度优先级队列
- 符号链接快速跳过

#### 10.2 内存优化

- 大量文件时避免一次性加载所有 URL
- 列表虚拟化 / 分页加载（现有基础上优化）
- 缩略图缓存池，及时释放非可见区域资源

#### 10.3 UI 响应性

- 所有磁盘操作严格在后台队列
- 进度更新节流（已有基础，进一步优化）
- 大列表用 `LazyVStack` / `LazyVGrid`（已使用，确认无遗漏）

#### 10.4 性能基准测试

- 建立基准测试套件
- 对 1000+ 模板、100+ 资源库的场景做性能测试

---

### 阶段 11：反馈与崩溃报告

**目标**：上线后能快速发现和定位问题。

#### 11.1 崩溃报告

- 可选：集成 `PLCrashReporter` 或直接用 `ReportCrash`
- 用户可选择是否发送
- 崩溃报告附带基本系统信息（macOS 版本、机型、App 版本）

#### 11.2 反馈功能

- 内置反馈表单：问题类型、描述、联系方式
- 可附加日志文件
- 发送到指定邮箱或 API（可配置）

#### 11.3 隐私设计

- 所有数据收集默认关闭
- 首次启动明确询问
- 设置中可随时开关
- 符合 GDPR / 国内隐私法规

---

### 阶段 12：文档与资源

**目标**：专业产品该有的物料。

#### 12.1 用户手册

- 快速入门指南
- 功能详解
- 常见问题 FAQ
- 故障排查

#### 12.2 应用截图

- 清理模块截图
- 模板库截图
- 设置界面截图
- 深色模式截图

#### 12.3 官网落地页（可选）

- 产品介绍
- 功能亮点
- 下载按钮
- 定价（如收费）

---

## 四、文件变更清单

### 新增文件（核心）

```
native/Sources/FCPXToolbox/
├── App/
│   └── Commands.swift                  # 主菜单命令
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
│   │   └── Theme.swift                 # 重构现有 Theme
│   └── Components/
│       ├── Card.swift                  # 从 Theme 中抽出
│       ├── EmptyStateView.swift
│       └── ProgressBar.swift
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
├── FormattingTests.swift
├── PreferencesTests.swift
└── Fixtures/
    ├── SampleLibrary.fcpbundle/
    └── SampleTemplates/

scripts/
├── notarize.sh                         # 公证脚本
├── create-dmg.sh                       # DMG 打包
└── release.sh                          # 完整发布流程
```

### 修改文件

| 文件 | 改动说明 |
| --- | --- |
| `FCPXToolboxApp.swift` | 添加 Settings 场景、菜单、生命周期事件 |
| `RootView.swift` | 接入欢迎引导、适配新主题 |
| `Theme.swift` | 重构为动态主题系统，支持深色模式 |
| `CleanupView.swift` | 字符串本地化、右键菜单、快捷键 |
| `CleanupViewModel.swift` | 接入偏好存储、历史记录、日志 |
| `Scanner.swift` | 错误标准化、日志、性能优化 |
| `Cleaner.swift` | 错误标准化、日志 |
| `TemplateLibraryView.swift` | 本地化、右键菜单 |
| `TemplateLibraryViewModel.swift` | 接入偏好、日志 |
| `Package.swift` | 添加 Sparkle 等依赖、资源文件 |
| `build-native.sh` | 增强 Release 构建、签名 |
| `README.md` | 更新功能列表、安装说明、截图 |

---

## 五、依赖新增

| 依赖 | 用途 | 可选 |
| --- | --- | --- |
| Sparkle 2.x | 自动更新 | 是（独立分发需要） |
| XCTest 已有 | 单元测试 | 否 |
| OSLog 系统框架 | 日志 | 否（系统内置） |

> 注：尽可能使用系统原生框架，减少第三方依赖，保证 App 体积小、启动快。

---

## 六、风险与应对

| 风险 | 影响 | 应对策略 |
| --- | --- | --- |
| 签名与公证需要 Apple Developer 账号 | 无法正式分发 | 先完成功能开发，签名步骤在拿到证书后执行 |
| 深色模式适配工作量大 | UI 细节问题多 | 先完成动态颜色系统，再逐个模块验证 |
| 本地化字符串遗漏 | 部分界面仍为中文 | 建立本地化 checklist，逐屏检查 |
| 测试用 fixture 构建复杂 | 测试开发慢 | 先做核心逻辑测试，fixture 逐步丰富 |
| Sparkle 集成复杂 | 自动更新不可靠 | 先手动发布，后续再加上自动更新 |

---

## 七、发布里程碑

| 版本 | 内容 | 目标 |
| --- | --- | --- |
| v0.4 | 工程基础 + 测试 + 日志 + 错误处理 | 内部质量达标 |
| v0.5 | 深色模式 + 国际化 + 设置 + 关于 | 产品完整性 |
| v0.6 | 欢迎引导 + 快捷键 + 菜单 + 功能增强 | 用户体验完善 |
| v0.7 | 性能优化 + 测试覆盖达标 | 大体量场景流畅 |
| v0.8 | 签名 + DMG + 公证 | 可独立分发 |
| v0.9 | Sparkle 自动更新 + 反馈 + 崩溃报告 | 可持续迭代 |
| v1.0 | 文档 + 截图 + 最终打磨 | 正式发布 |

---

## 八、验证标准

每个阶段完成后，需满足以下验证标准：

1. **功能验证**：新功能按设计正常工作
2. **构建验证**：Release 构建无警告、无错误
3. **测试验证**：新增代码有对应测试，核心逻辑覆盖达标
4. **UI 验证**：深浅模式下无显示问题
5. **本地化验证**：中英文切换无遗漏
6. **性能验证**：扫描/清理性能不退化
7. **内存验证**：无内存泄漏（Instrument 检查）

---

*计划版本：v1.0*
*生成日期：2026-06-24*
