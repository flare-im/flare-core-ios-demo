# flare-core-ios-app

`flare-core-apple-sdk` 的生产级 iOS IM 应用模板，采用 **feature-first MVVM** 架构。

## 目录结构

```text
Sources/FlareImApp/
├── App/              # 入口 + 组合根/协调器(FlareImApp、FlareAppStore)
├── Core/             # 跨特性共享层(映射 SDK 的协议化模块)
│   ├── Sdk/          #   SdkClientFactory —— client 创建 DI 缝(可注入 mock)
│   ├── Session/      #   AppSession —— 生命周期/认证/连接/事件(唯一持 client)
│   ├── Data/         #   ViewDataRepository —— 会话/消息 + view-delta 引擎
│   ├── Environment/  #   AppEnvironment —— UI/导航 + 共享 loginDraft + run()/Lab 操作基建
│   ├── Domain/       #   AppModels、AppSdkModels、SdkModelMapper
│   └── DesignSystem/ #   FlareDesign、FlareFormatters、CommonViews
└── Features/         # 每特性 View + ViewModel 同处
    ├── Auth/         #   LoginView
    ├── Messaging/    #   ConversationListView + ChatView + MessagingViewModel(列表与聊天合一)
    ├── Search/       #   SearchView + SearchViewModel
    ├── Settings/     #   SettingsView
    ├── SdkLab/       #   SdkLabView + SdkLabViewModel(诊断/媒体/能力 三子 Lab)
    └── Shell/        #   RootWorkbenchView
FFI/                  # Rust FFI 产物(gitignored,scripts/sync_ffi.sh 同步)
scripts/              # sync_ffi.sh
Tests/                # FlareImAppTests
```

**架构**：`View → ViewModel → {AppSession, ViewDataRepository, AppEnvironment} → SDK 协议门面 → FFI`。
ViewModel 经 `environmentObject` 注入;协调器 `FlareAppStore` 装配 Core + 各特性 VM 并持登录/登出/释放编排。
DI 缝(`SdkClientFactory`)让 ViewModel 可注入 mock `FlareImClientProtocol` 单测。参考实现：`flare-core-flutter-app`。

## 运行

> 前置：工作区已构建 Rust FFI 产物到 `native/artifacts/`（host `.dylib` + iOS `.a` 切片）。

```bash
# 1. 同步 FFI 产物到 FFI/
bash scripts/sync_ffi.sh

# 2a. iOS 模拟器（推荐）—— 用 xcodegen 生成 app 工程并运行
xcodegen generate                                          # 需 `brew install xcodegen`
xcodebuild -project FlareImApp.xcodeproj -scheme FlareImExampleApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .build-xcode build
xcrun simctl boot 'iPhone 17' || true
xcrun simctl install booted .build-xcode/Build/Products/Debug-iphonesimulator/FlareImExampleApp.app
xcrun simctl launch booted com.flare.im.example.app

# 2b. macOS 宿主 —— 无界面验证 FFI 链路
FLARE_FFI_DYLIB="$PWD/FFI/libflare_im_core_sdk_ffi.dylib" swift test
```

要点：
- iOS 经 **静态 `.a` + `dlopen(nil)`** 解析 C-ABI 符号，工程已在 `project.yml` 配 **`-force_load` + `-export_dynamic`**（否则链接期死剥 / `dlsym` 找不到符号）。
- `project.yml` 是工程的**源**（提交）；`FlareImApp.xcodeproj` / `.build-xcode` 为生成物（已 gitignore）。
- 需 Swift 6.x 工具链（Xcode 16+；`FlareNativeBindings` 的 C 函数 binding 已修 `@convention(c)`，适配 Swift 6.3）。
