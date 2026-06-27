import Combine
import FlareCoreAppleSDK
import SwiftUI

/// 设置特性 ViewModel：外观/登录默认值的读写绑定、会话只读态，以及诊断刷新与会话清理动作。
/// SettingsView 只依赖它，不再直接碰 `store`/`environment`/`sdkLab`。
@MainActor
final class SettingsViewModel: ObservableObject {
    private let session: AppSession
    private let environment: AppEnvironment
    private let sdkLab: SdkLabViewModel
    private weak var lifecycle: AppLifecycle?
    private var cancellables = Set<AnyCancellable>()

    init(
        session: AppSession,
        environment: AppEnvironment,
        sdkLab: SdkLabViewModel,
        lifecycle: AppLifecycle? = nil
    ) {
        self.session = session
        self.environment = environment
        self.sdkLab = sdkLab
        self.lifecycle = lifecycle
        for publisher in [session.objectWillChange, environment.objectWillChange] {
            publisher.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        }
    }

    /// 由组合根在装配后回填（打破 store ↔ VM 强引用环）。
    func bind(lifecycle: AppLifecycle) {
        self.lifecycle = lifecycle
    }

    var themeChoice: Binding<ThemeChoice> {
        Binding(get: { self.environment.themeChoice }, set: { self.environment.themeChoice = $0 })
    }

    func draftBinding<Value>(_ keyPath: WritableKeyPath<LoginDraft, Value>) -> Binding<Value> {
        Binding(
            get: { self.environment.loginDraft[keyPath: keyPath] },
            set: { newValue in
                var draft = self.environment.loginDraft
                draft[keyPath: keyPath] = newValue
                self.environment.loginDraft = draft
            }
        )
    }

    var currentUserId: String? { session.currentUserId }
    var connectionState: ConnectionState { session.connectionState }
    var runtimeStatus: RuntimeStatus { environment.runtimeStatus }

    func refreshDiagnostics() async { await sdkLab.refreshDiagnostics() }
    func logout() async { await lifecycle?.logout() }
    func dispose() async { await lifecycle?.dispose() }

    // MARK: - 媒体缓存管理（SDK 托管的磁盘缓存：用量 / 上限 / 清空）
    @Published var cacheStats: String?

    func refreshCacheStats() async {
        guard let client = session.client else { return }
        if let raw = try? await client.media.getMediaCacheStats() {
            cacheStats = Self.formatCacheStats(raw)
        }
    }

    func setCacheMaxBytes(_ bytes: Int64) async {
        guard let client = session.client else { return }
        _ = try? await client.media.setMediaCacheMaxBytes(["maxBytes": AnySendable(bytes)])
        await refreshCacheStats()
    }

    func clearCache() async {
        guard let client = session.client else { return }
        try? await client.media.clearMediaCache()
        await refreshCacheStats()
    }

    private static func formatCacheStats(_ stats: [String: AnySendable]) -> String {
        func num(_ keys: [String]) -> Int64? {
            for k in keys {
                let v = stats[k]?.value
                if let n = v as? Int64 { return n }
                if let n = v as? Int { return Int64(n) }
                if let n = v as? Double { return Int64(n) }
                if let n = v as? NSNumber { return n.int64Value }
            }
            return nil
        }
        func mb(_ b: Int64) -> String { String(format: "%.1f MB", Double(b) / 1_048_576.0) }
        let used = num(["usedBytes", "totalBytes", "sizeBytes", "bytes"])
        let maxB = num(["maxBytes", "limitBytes", "capacityBytes"])
        let count = num(["entryCount", "fileCount", "count", "entries"])
        var parts = used.map(mb) ?? "—"
        if let maxB { parts += " / \(mb(maxB))" }
        if let count { parts += " · \(count) files" }
        return parts
    }
}
