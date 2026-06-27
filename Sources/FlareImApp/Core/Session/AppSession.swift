import Combine
import Foundation
import FlareCoreAppleSDK

/// 跨切面会话核心:拥有 SDK 客户端的生命周期 + 认证态 + 连接态 + 原始事件流。
///
/// 从 god-store 抽出 —— 这是**唯一**持有 `any FlareImClientProtocol` 的地方;ViewModel / Repository
/// 经它拿到客户端的协议门面去调用。事件经回调路由到数据层(`onViewUpdate`)与聊天层(`onMessageSendFailed`),
/// 避免 Session 反向依赖具体的会话/消息状态。
@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var currentUserId: String?
    @Published private(set) var isLoggedIn = false
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var eventLog: [EventLogEntry] = []

    /// 唯一的客户端持有点(其余层经协议门面使用)。
    private(set) var client: (any FlareImClientProtocol)?

    /// 事件路由钩子(由数据层/聊天层注入)。@MainActor 闭包:回调里可直接调 @MainActor 状态。
    var onViewUpdate: (@MainActor (ViewUpdate) -> Void)?
    var onMessageSendFailed: (@MainActor (String) -> Void)?

    private let clientFactory: SdkClientFactory
    private var eventSubscriptions: [any EventSubscription] = []
    private var nativeEventSubscription: [String: AnySendable]?

    nonisolated init(clientFactory: SdkClientFactory = DefaultSdkClientFactory()) {
        self.clientFactory = clientFactory
    }

    /// 创建 → 订阅 → init → 取 token → 登录 → 订阅原生事件。`progress` 回报阶段供上层更新 UI 状态。
    @discardableResult
    func start(draft: LoginDraft, dataURL: URL, progress: @MainActor (String) -> Void) async throws -> any FlareImClientProtocol {
        progress("Creating Apple SDK client")
        let client = try clientFactory.makeClient(libraryPath: draft.libraryPath)
        self.client = client
        installEventSubscriptions(client)

        progress("Initializing SDK")
        var initConfig = try draft.sdkTransportConfig()
        initConfig.merge([
            "dataUrl": AnySendable(dataURL.absoluteString),
            "tenantId": AnySendable(draft.tenantId),
            "platform": AnySendable("apple"),
            "runtime": AnySendable("swiftui-example")
        ]) { _, new in new }
        try await client.`init`(initConfig)

        progress("Generating core token")
        let ttl = UInt64(draft.tokenTtlSeconds) ?? 86400
        let token = try await resolveToken(draft: draft, ttl: ttl)

        progress("Logging in")
        try await client.login([
            "userId": AnySendable(draft.userId),
            "token": AnySendable(token)
        ])
        try await subscribeNativeEvents(client)

        // 配置 SDK 托管的媒体磁盘缓存（LRU + 去重，核心已实现）：设根目录 + 上限，
        // 之后消息媒体经 media.cacheRemoteMedia 落到这里（离线可用、不重复下载）。
        let mediaCacheRoot = dataURL.appendingPathComponent("media-cache").path
        _ = try? await client.media.setMediaCacheRoot(["root": AnySendable(mediaCacheRoot)])
        _ = try? await client.media.setMediaCacheMaxBytes(["maxBytes": AnySendable(Int64(268_435_456))]) // 256MB

        currentUserId = draft.userId
        isLoggedIn = true
        connectionState = try await client.connection.getConnectionState()
        return client
    }

    func logout() async throws {
        guard let client else { throw AppStoreError(message: "SDK client is not initialized") }
        try await client.logout()
        isLoggedIn = false
        currentUserId = nil
        nativeEventSubscription = nil
        connectionState = try await client.connection.getConnectionState()
    }

    func dispose() async throws {
        eventSubscriptions.forEach { $0.unsubscribe() }
        eventSubscriptions.removeAll()
        try await client?.dispose()
        client = nil
        isLoggedIn = false
        currentUserId = nil
        nativeEventSubscription = nil
        connectionState = .disconnected
    }

    func refreshConnectionState() async throws {
        guard let client else { return }
        connectionState = try await client.connection.getConnectionState()
    }

    /// SDK Lab 的 `events.unsubscribe_all` 后重装订阅。
    func reinstallEventSubscriptions() {
        guard let client else { return }
        eventSubscriptions.removeAll()
        installEventSubscriptions(client)
    }

    func resolveToken(draft: LoginDraft, ttl: UInt64) async throws -> String {
        let override = draft.tokenOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty { return override }
        guard let client else { throw AppStoreError(message: "SDK client is not initialized") }
        return try await client.generateCoreToken(CoreTokenRequest(
            userId: draft.userId,
            secret: draft.tokenSecret,
            issuer: draft.tokenIssuer,
            ttlSecs: ttl,
            deviceId: nil,
            tenantId: draft.tenantId
        )).token
    }

    private func installEventSubscriptions(_ client: any FlareImClientProtocol) {
        eventSubscriptions.forEach { $0.unsubscribe() }
        eventSubscriptions = [
            client.events.onInitialized { [weak self] event in
                Task { @MainActor in self?.appendEvent("lifecycle", name: event.name.rawValue, detail: event.operation) }
            },
            client.events.onLoginSucceeded { [weak self] event in
                Task { @MainActor in self?.appendEvent("lifecycle", name: event.name.rawValue, detail: event.userId ?? "") }
            },
            client.events.onLoggedOut { [weak self] event in
                Task { @MainActor in self?.appendEvent("lifecycle", name: event.name.rawValue, detail: event.operation) }
            },
            client.events.onConnectReady { [weak self] event in
                Task { @MainActor in self?.appendEvent("connection", name: event.name.rawValue, detail: event.reason ?? "") }
            },
            client.events.onDisconnected { [weak self] event in
                Task { @MainActor in self?.appendEvent("connection", name: event.name.rawValue, detail: event.reason ?? "") }
            },
            client.events.onMessageReceived { [weak self] event in
                Task { @MainActor in
                    let message = SdkModelMapper.messageFromCore(event.message)
                    self?.appendEvent("message", name: "received", detail: message.previewText)
                }
            },
            client.events.onViewUpdated { [weak self] event in
                Task { @MainActor in
                    self?.appendEvent("view", name: event.kind, detail: event.viewId)
                    self?.onViewUpdate?(event)
                }
            },
            client.events.onMessageSendAck { [weak self] event in
                Task { @MainActor in self?.appendEvent("message", name: "send_ack", detail: event.ack.clientMsgId) }
            },
            client.events.onMessageSendFailed { [weak self] event in
                Task { @MainActor in
                    self?.onMessageSendFailed?(event.clientMsgId)
                    self?.appendEvent("message", name: "send_failed", detail: event.reason)
                }
            },
            client.events.onConversationChanged { [weak self] event in
                Task { @MainActor in self?.appendEvent("conversation", name: event.name.rawValue, detail: event.conversationId ?? "") }
            },
            client.events.onCapabilityChanged { [weak self] event in
                Task { @MainActor in self?.appendEvent("capability", name: event.name.rawValue, detail: event.capability ?? "") }
            }
        ]
    }

    private func subscribeNativeEvents(_ client: any FlareImClientProtocol) async throws {
        nativeEventSubscription = try await client.events.subscribeEvents([
            "sources": AnySendable(["view", "message", "conversation", "sync"])
        ])
    }

    private func appendEvent(_ domain: String, name: String, detail: String) {
        eventLog.insert(EventLogEntry(time: Date(), domain: domain, name: name, detail: detail), at: 0)
        if eventLog.count > 120 { eventLog.removeLast(eventLog.count - 120) }
    }
}
