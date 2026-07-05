import Foundation
import CoreGraphics
import FlareCoreAppleSDK

enum AppSection: String, CaseIterable, Identifiable {
    case conversations
    case search
    case sdkLab
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .conversations: return String(localized: "Messages")
        case .search: return String(localized: "Search")
        case .sdkLab: return String(localized: "SDK Status")
        case .settings: return String(localized: "Settings")
        }
    }

    var symbol: String {
        switch self {
        case .conversations: return "bubble.left.and.bubble.right"
        case .search: return "magnifyingglass"
        case .sdkLab: return "testtube.2"
        case .settings: return "gearshape"
        }
    }
}

enum RuntimeStatus: Equatable {
    case idle
    case loading(String)
    case ready
    case offline(String)
    case error(String)
    case unavailable(String)

    var title: String {
        switch self {
        case .idle: return "Idle"
        case .loading(let message): return message
        case .ready: return "Ready"
        case .offline(let reason): return "Offline: \(reason)"
        case .error(let message): return "Error: \(message)"
        case .unavailable(let message): return "Unavailable: \(message)"
        }
    }

    var isBlocking: Bool {
        switch self {
        case .unavailable: return true
        default: return false
        }
    }
}

enum RuntimeTone: Equatable {
    case neutral
    case info
    case success
    case warning
    case danger
}

extension RuntimeStatus {
    var productLabel: String {
        switch self {
        case .idle: return "Not connected"
        case .loading(let message): return message
        case .ready: return "Online"
        case .offline: return "Offline"
        case .error: return "Needs attention"
        case .unavailable: return "Unavailable"
        }
    }

    var productDetail: String? {
        switch self {
        case .idle:
            return "Sign in to start receiving messages."
        case .loading:
            return nil
        case .ready:
            return "Messages, sync, and SDK events are active."
        case .offline(let reason), .error(let reason), .unavailable(let reason):
            return reason
        }
    }

    var productTone: RuntimeTone {
        switch self {
        case .idle: return .neutral
        case .loading: return .info
        case .ready: return .success
        case .offline, .unavailable: return .warning
        case .error: return .danger
        }
    }

    var productIcon: String {
        switch self {
        case .idle: return "circle"
        case .loading: return "arrow.triangle.2.circlepath"
        case .ready: return "checkmark.circle.fill"
        case .offline: return "wifi.slash"
        case .error: return "exclamationmark.triangle.fill"
        case .unavailable: return "nosign"
        }
    }
}

enum ConversationFilter: String, CaseIterable, Identifiable {
    case all
    case unread
    case mentions
    case pinned
    case archived
    case muted
    case drafts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return String(localized: "All")
        case .unread: return String(localized: "Unread")
        case .mentions: return String(localized: "Mentions")
        case .pinned: return String(localized: "Pinned")
        case .archived: return String(localized: "Archived")
        case .muted: return String(localized: "Muted")
        case .drafts: return String(localized: "Drafts")
        }
    }
}

enum StartConversationKind: String, CaseIterable, Identifiable {
    case single
    case group

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: return String(localized: "Direct")
        case .group: return String(localized: "Group")
        }
    }
}

enum ThemeChoice: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum LoginTransportMode: String, CaseIterable, Identifiable {
    case websocket
    case quic
    case race

    var id: String { rawValue }

    var title: String {
        switch self {
        case .websocket: return "WebSocket"
        case .quic: return "QUIC"
        case .race: return "QUIC Race"
        }
    }
}

enum LoginTransportConfigError: LocalizedError {
    case missingWebSocketUrl
    case missingQuicUrl

    var errorDescription: String? {
        switch self {
        case .missingWebSocketUrl: return "WebSocket URL is required"
        case .missingQuicUrl: return "QUIC URL is required for selected transport"
        }
    }
}

enum LabTab: String, CaseIterable, Identifiable {
    case diagnostics
    case lifecycle
    case conversations
    case messages
    case media
    case capabilities
    case events
    case coverage

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct LoginDraft: Equatable {
    var userId = ""
    var wsUrl = LoginDefaults.webSocketURL
    var transportMode: LoginTransportMode = .websocket
    var quicUrl = LoginDefaults.quicURL
    var tlsCaCertPath = ""
    var tenantId = LoginDefaults.tenantId
    var tokenSecret = LoginDefaults.tokenSecret()
    var tokenIssuer = LoginDefaults.tokenIssuer
    var tokenTtlSeconds = LoginDefaults.tokenTtlSeconds
    var libraryPath = ""
    var dataSubfolder = "flare-core-ios-app"
    var tokenOverride = ""

    var visibleServerAddressLabel: String {
        switch transportMode {
        case .websocket:
            return String(localized: "WebSocket server URL")
        case .quic:
            return String(localized: "QUIC server URL")
        case .race:
            return String(localized: "Primary server URL")
        }
    }

    var visibleServerAddressPlaceholder: String {
        switch transportMode {
        case .websocket:
            return LoginDefaults.webSocketURL
        case .quic, .race:
            return LoginDefaults.quicURL
        }
    }

    var visibleServerAddress: String {
        switch transportMode {
        case .websocket:
            return wsUrl
        case .quic, .race:
            return quicUrl
        }
    }

    var secondaryServerAddressLabel: String? {
        transportMode == .race ? String(localized: "Fallback WebSocket URL") : nil
    }

    var secondaryServerAddressPlaceholder: String? {
        transportMode == .race ? LoginDefaults.webSocketURL : nil
    }

    var secondaryServerAddress: String? {
        transportMode == .race ? wsUrl : nil
    }

    mutating func setVisibleServerAddress(_ value: String) {
        switch transportMode {
        case .websocket:
            wsUrl = value
        case .quic, .race:
            quicUrl = value
        }
    }

    mutating func setSecondaryServerAddress(_ value: String) {
        if transportMode == .race {
            wsUrl = value
        }
    }

    func sdkTransportConfig() throws -> [String: AnySendable] {
        let ws = wsUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let quic = quicUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let tls = tlsCaCertPath.trimmingCharacters(in: .whitespacesAndNewlines)
        var config: [String: AnySendable] = [:]
        if !tls.isEmpty {
            config["tlsCaCertPath"] = AnySendable(tls)
        }

        switch transportMode {
        case .websocket:
            guard !ws.isEmpty else { throw LoginTransportConfigError.missingWebSocketUrl }
            config["wsUrl"] = AnySendable(ws)
            config["transportPolicy"] = AnySendable("websocket_only")
            config["defaultTransport"] = AnySendable("websocket")
        case .quic:
            guard !quic.isEmpty else { throw LoginTransportConfigError.missingQuicUrl }
            config["quicUrl"] = AnySendable(quic)
            config["defaultTransport"] = AnySendable("quic")
            config["transportPolicy"] = AnySendable("auto")
            config["protocolRaceOrder"] = AnySendable(["quic"])
        case .race:
            guard !quic.isEmpty else { throw LoginTransportConfigError.missingQuicUrl }
            guard !ws.isEmpty else { throw LoginTransportConfigError.missingWebSocketUrl }
            config["quicUrl"] = AnySendable(quic)
            config["wsUrl"] = AnySendable(ws)
            config["defaultTransport"] = AnySendable("quic")
            config["transportPolicy"] = AnySendable("protocol_race")
            config["protocolRaceOrder"] = AnySendable(["quic", "websocket"])
        }
        return config
    }
}

enum LoginDefaults {
    static let webSocketURL = "ws://127.0.0.1:60051/ws"
    static let quicURL = "quic://127.0.0.1:60052"
    static let tenantId = "0"
    static let tokenIssuer = "flare-im-core"
    static let tokenTtlSeconds = "3600"
    static let fallbackTokenSecret = "flare-dev-secret"

    static func tokenSecret(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        sourceFile: String = #filePath,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath
    ) -> String {
        if let secret = firstNonEmpty(environment, keys: [
            "VITE_FLARE_TOKEN_SECRET",
            "ACCESS_GATEWAY_TOKEN_SECRET",
            "FLARE_API_GATEWAY_TOKEN_SECRET"
        ]) {
            return secret
        }
        let configuredPath = environment["FLARE_DEV_TOKEN_SECRET_FILE"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = ([configuredPath] + localDevTokenSecretCandidates(
            sourceFile: sourceFile,
            currentDirectoryPath: currentDirectoryPath
        )).compactMap { $0 }
        for path in candidates where fileManager.isReadableFile(atPath: path) {
            if let secret = try? String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
               !secret.isEmpty {
                return secret
            }
        }
        return fallbackTokenSecret
    }

    private static func firstNonEmpty(_ environment: [String: String], keys: [String]) -> String? {
        for key in keys {
            let value = environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty { return value }
        }
        return nil
    }

    private static func localDevTokenSecretCandidates(sourceFile: String, currentDirectoryPath: String) -> [String] {
        let anchors = [
            URL(fileURLWithPath: sourceFile).deletingLastPathComponent(),
            URL(fileURLWithPath: currentDirectoryPath, isDirectory: true),
            Bundle.main.bundleURL.deletingLastPathComponent()
        ]
        var seen = Set<String>()
        var candidates: [String] = []
        for anchor in anchors {
            var cursor = anchor.standardizedFileURL
            for _ in 0..<12 {
                for relativePath in [
                    "flare-im-core/logs/.dev-token-secret",
                    "../flare-im-core/logs/.dev-token-secret",
                    "../../../flare-im-core/logs/.dev-token-secret"
                ] {
                    let path = cursor.appendingPathComponent(relativePath).standardizedFileURL.path
                    if seen.insert(path).inserted {
                        candidates.append(path)
                    }
                }
                let parent = cursor.deletingLastPathComponent()
                if parent.path == cursor.path { break }
                cursor = parent
            }
        }
        return candidates
    }
}

struct StartConversationDraft: Equatable {
    var peerUserId = ""
    var groupUserIds = ""
}

struct SearchDraft: Equatable {
    var keyword = ""
    var senderId = ""
    var conversationScoped = true
    var includeRecalled = false
    var kind: MessageSearchKind = .message
}

struct MediaLabDraft: Equatable {
    var fileId = ""
    var filePath = ""
    var cacheMaxBytes = "268435456"
    var downloadSubfolder = "flare-ios"
}

struct CapabilityLabDraft: Equatable {
    var userId = ""
    var capability = "call"
    var operation = "probe"
    var callSignalType = "offer"
    var payload = "{}"
}

struct EventLogEntry: Identifiable, Equatable {
    let id = UUID()
    let time: Date
    let domain: String
    let name: String
    let detail: String
}

struct LabResult: Identifiable, Equatable {
    let id = UUID()
    let time: Date
    let operation: String
    let status: String
    let detail: String
}

struct CoverageRow: Identifiable, Equatable {
    let id = UUID()
    let family: String
    let api: String
    let status: String
    let entryPoint: String
}

extension MessageContent {
    var previewText: String {
        if contentType == .sticker { return PreviewCopy.bracket(PreviewCopy.sticker) }
        if contentType == .emoji {
            if let emoji = stringValue("emoji", "key") {
                return EmojiPackTextFormatter.formatEmojiValue(emoji)
            }
            return PreviewCopy.bracket(PreviewCopy.emoji)
        }
        let preferredKeys = [
            "text", "plainText", "searchText", "body", "title", "name", "file_name", "filename", "url",
            "emoji", "sticker_id", "summary", "markdown", "html", "address"
        ]
        for key in preferredKeys {
            if let value = stringValue(key) {
                return PreviewStorageFormat.format(value)
            }
        }
        if let first = data.values.compactMap({ $0.value as? String }).first(where: { !$0.isEmpty }) {
            return PreviewStorageFormat.format(first)
        }
        return contentType.title
    }

    func stringValue(_ keys: String...) -> String? {
        for key in keys {
            if let value = unwrappedValue(for: key) as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    func nestedStringValue(_ container: String, _ keys: String...) -> String? {
        for key in keys {
            if let value = nestedValue(container, key) as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    func int64Value(_ keys: String...) -> Int64? {
        for key in keys {
            if let value = int64(from: unwrappedValue(for: key)) {
                return value
            }
        }
        return nil
    }

    func uint64Value(_ keys: String...) -> UInt64? {
        for key in keys {
            if let value = uint64(from: unwrappedValue(for: key)) {
                return value
            }
        }
        return nil
    }

    func nestedUInt64Value(_ container: String, _ keys: String...) -> UInt64? {
        for key in keys {
            if let value = uint64(from: nestedValue(container, key)) {
                return value
            }
        }
        return nil
    }

    func nestedIntValue(_ container: String, _ keys: String...) -> Int? {
        for key in keys {
            if let value = int64(from: nestedValue(container, key)) {
                return Int(value)
            }
        }
        return nil
    }

    var mediaSourceURL: URL? {
        if let raw = nestedStringValue(
            "source",
            "url", "cdnUrl", "cdn_url", "mediaUrl", "media_url",
            "downloadUrl", "download_url", "accessUrl", "access_url",
            "tempUrl", "temp_url", "sourceUrl", "source_url"
        )
            ?? stringValue(
                "url", "cdnUrl", "cdn_url", "mediaUrl", "media_url",
                "downloadUrl", "download_url", "accessUrl", "access_url",
                "tempUrl", "temp_url", "sourceUrl", "source_url"
            ) {
            return URL(string: raw)
        }
        return nil
    }

    var mediaFileId: String? {
        nestedStringValue("source", "uuid", "fileId", "file_id", "imageId", "audioId", "videoId", "mediaId", "media_id", "id")
            ?? stringValue("fileId", "file_id", "imageId", "audioId", "videoId", "mediaId", "media_id", "uuid", "id")
    }

    var mediaResolveKey: String {
        [
            contentType.rawValue,
            mediaFileId ?? "",
            mediaSourceURL?.absoluteString ?? ""
        ].joined(separator: "|")
    }

    var mediaMimeType: String? {
        nestedStringValue("source", "mimeType") ?? stringValue("mimeType")
    }

    var mediaByteSize: UInt64? {
        nestedUInt64Value("source", "size") ?? uint64Value("size")
    }

    var mediaDurationMs: Int? {
        nestedIntValue("source", "durationMs") ?? int64Value("durationMs").map(Int.init)
    }

    var mediaDurationText: String? {
        guard let mediaDurationMs, mediaDurationMs > 0 else { return nil }
        let totalSeconds = max(1, Int((Double(mediaDurationMs) / 1000).rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var imagePixelSize: CGSize? {
        let width = nestedIntValue("source", "width") ?? nestedIntValue("thumbnail", "width")
        let height = nestedIntValue("source", "height") ?? nestedIntValue("thumbnail", "height")
        guard let width, let height, width > 0, height > 0 else { return nil }
        return CGSize(width: width, height: height)
    }

    var fileDisplayName: String {
        stringValue("name", "fileName", "filename") ?? PreviewCopy.file
    }

    private func unwrappedValue(for key: String) -> Any? {
        if let direct = data[key]?.value {
            if let nested = value(in: direct, for: key) {
                return nested
            }
            return direct
        }
        guard let payload = contentPayloadValue else { return nil }
        return value(in: payload, for: key)
    }

    private func nestedValue(_ container: String, _ key: String) -> Any? {
        if let raw = data[container]?.value, let value = value(in: raw, for: key) {
            return value
        }
        guard
            let payload = contentPayloadValue,
            let nestedContainer = value(in: payload, for: container)
        else {
            return nil
        }
        return value(in: nestedContainer, for: key)
    }

    private var contentPayloadValue: Any? {
        guard let key = contentPayloadKey else { return nil }
        return data[key]?.value
    }

    private var contentPayloadKey: String? {
        switch contentType {
        case .image: return "image"
        case .video: return "video"
        case .audio: return "audio"
        case .file: return "file"
        case .sticker: return "sticker"
        case .emoji: return "emoji"
        case .imageGroup: return "imageGroup"
        case .location: return "location"
        case .card: return "card"
        case .linkCard: return "linkCard"
        case .miniProgram: return "miniProgram"
        case .richText: return "richText"
        case .quote: return "quote"
        case .forward: return "forward"
        case .thread: return "thread"
        case .vote: return "vote"
        case .task: return "task"
        case .schedule: return "schedule"
        case .announcement: return "announcement"
        case .system, .notification, .custom, .placeholder, .text:
            return nil
        }
    }

    private func value(in raw: Any?, for key: String) -> Any? {
        if let wrapped = raw as? AnySendable {
            return value(in: wrapped.value, for: key)
        }
        if let map = raw as? [String: AnySendable] {
            return map[key]?.value
        }
        if let map = raw as? [String: Any] {
            if let value = map[key] as? AnySendable {
                return value.value
            }
            return map[key]
        }
        return nil
    }

    private func int64(from value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? UInt64 { return Int64(value) }
        if let value = value as? Double { return Int64(value) }
        if let value = value as? String { return Int64(value) }
        return nil
    }

    private func uint64(from value: Any?) -> UInt64? {
        if let value = value as? UInt64 { return value }
        if let value = value as? Int, value >= 0 { return UInt64(value) }
        if let value = value as? Int64, value >= 0 { return UInt64(value) }
        if let value = value as? Double, value >= 0 { return UInt64(value) }
        if let value = value as? String { return UInt64(value) }
        return nil
    }
}

extension MessageContentType {
    var title: String {
        rawValue
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

extension MessagePreview {
    var previewText: String {
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let value = child.value as? String, !value.isEmpty {
                return PreviewStorageFormat.format(value)
            }
        }
        return PreviewCopy.message
    }
}

enum PreviewStorageKind: Equatable {
    case text
    case sticker
    case emoji(String?)
}

enum PreviewStorageFormat {
    static func kind(_ raw: String) -> PreviewStorageKind {
        guard let payload = payload(raw) else { return .text }
        switch payload.key {
        case "im.preview.sticker":
            return .sticker
        case "im.preview.emoji":
            return .emoji(string(payload.args["e"]))
        default:
            return .text
        }
    }

    static func format(_ raw: String) -> String {
        guard let payload = payload(raw) else { return EmojiPackTextFormatter.format(raw) }
        let args = payload.args
        switch payload.key {
        case "im.preview.user_text":
            return EmojiPackTextFormatter.format(string(args["t"]) ?? raw)
        case "im.preview.sticker":
            return PreviewCopy.bracket(PreviewCopy.sticker)
        case "im.preview.emoji":
            return string(args["e"]).map { EmojiPackTextFormatter.formatEmojiValue($0) } ?? PreviewCopy.bracket(PreviewCopy.emoji)
        case "im.preview.rich_text":
            return [string(args["title"]), string(args["body"])]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .ifEmpty(PreviewCopy.bracket(PreviewCopy.richText))
        case "im.preview.image":
            if (args["m"] as? Bool) == true { return PreviewCopy.bracket(PreviewCopy.gif) }
            return string(args["d"]) ?? PreviewCopy.bracket(PreviewCopy.image)
        case "im.preview.video":
            return string(args["d"]) ?? PreviewCopy.bracket(PreviewCopy.video)
        case "im.preview.audio":
            return string(args["d"]) ?? PreviewCopy.bracket(PreviewCopy.voice)
        case "im.preview.file":
            return string(args["n"]) ?? PreviewCopy.bracket(PreviewCopy.file)
        case "im.preview.location":
            if let label = string(args["label"]) { return "\(PreviewCopy.bracket(PreviewCopy.location)) \(label)" }
            return PreviewCopy.bracket(PreviewCopy.location)
        case "im.preview.card":
            if let label = string(args["label"]) { return "\(PreviewCopy.bracket(PreviewCopy.card)) \(label)" }
            return PreviewCopy.bracket(PreviewCopy.card)
        case "im.preview.vote":
            return PreviewCopy.bracket(PreviewCopy.vote)
        case "im.preview.task":
            if let title = string(args["t"]) { return "\(PreviewCopy.bracket(PreviewCopy.task)) \(title)" }
            return PreviewCopy.bracket(PreviewCopy.task)
        case "im.preview.schedule":
            return PreviewCopy.bracket(PreviewCopy.schedule)
        case "im.preview.announcement":
            if let title = string(args["t"]) { return "\(PreviewCopy.bracket(PreviewCopy.announcement)) \(title)" }
            return PreviewCopy.bracket(PreviewCopy.announcement)
        default:
            let value = string(args["t"]) ?? string(args["body"]) ?? string(args["title"])
            return value.map { EmojiPackTextFormatter.format($0) } ?? PreviewCopy.bracket(PreviewCopy.message)
        }
    }

    private static func payload(_ raw: String) -> (key: String, args: [String: Any])? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8) else { return nil }
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let key = object["k"] as? String,
            key.hasPrefix("im.preview.")
        else { return nil }
        return (key, object["a"] as? [String: Any] ?? [:])
    }

    private static func string(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum EmojiPackTextFormatter {
    static func format(_ text: String, locale: Locale = .current) -> String {
        guard !text.isEmpty else { return text }
        let pattern = #"\[([a-z][a-z0-9_]*)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return text }

        var output = ""
        var cursor = text.startIndex
        for match in matches {
            guard
                let fullRange = Range(match.range, in: text),
                let keyRange = Range(match.range(at: 1), in: text)
            else {
                continue
            }
            output += text[cursor..<fullRange.lowerBound]
            output += bracket(label(for: String(text[keyRange]), locale: locale))
            cursor = fullRange.upperBound
        }
        output += text[cursor...]
        return output
    }

    static func formatEmojiValue(_ raw: String, locale: Locale = .current) -> String {
        if let key = packKey(raw) {
            return bracket(label(for: key, locale: locale))
        }
        return format(raw, locale: locale)
    }

    private static func packKey(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let bracketed = try? NSRegularExpression(pattern: #"^\[([a-z][a-z0-9_]*)\]$"#) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            if let match = bracketed.firstMatch(in: trimmed, range: range),
               let keyRange = Range(match.range(at: 1), in: trimmed) {
                return String(trimmed[keyRange])
            }
        }
        if let bare = try? NSRegularExpression(pattern: #"^[a-z][a-z0-9_]*$"#) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            if bare.firstMatch(in: trimmed, range: range) != nil {
                return trimmed
            }
        }
        return nil
    }

    private static func label(for key: String, locale: Locale) -> String {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return normalized }
        if locale.identifier.lowercased().hasPrefix("zh"),
           let label = zhHansLabels[normalized] {
            return label
        }
        if let label = enLabels[normalized] {
            return label
        }
        return normalized
    }

    private static func bracket(_ value: String) -> String {
        "[\(value)]"
    }

    private static let zhHansLabels: [String: String] = [
        "face_with_open_mouth": "吃惊",
        "face_with_open_eyes_and_hand_over_mouth": "睁眼捂嘴"
    ]

    private static let enLabels: [String: String] = [
        "face_with_open_mouth": "face with open mouth",
        "face_with_open_eyes_and_hand_over_mouth": "face with open eyes and hand over mouth"
    ]
}

enum PreviewCopy {
    static var message: String { String(localized: "Message") }
    static var sticker: String { String(localized: "Sticker") }
    static var emoji: String { String(localized: "Emoji") }
    static var richText: String { String(localized: "Rich text") }
    static var gif: String { String(localized: "GIF") }
    static var image: String { String(localized: "Image") }
    static var video: String { String(localized: "Video") }
    static var voice: String { String(localized: "Voice") }
    static var file: String { String(localized: "File") }
    static var location: String { String(localized: "Location") }
    static var card: String { String(localized: "Contact") }
    static var vote: String { String(localized: "Vote") }
    static var task: String { String(localized: "Task") }
    static var schedule: String { String(localized: "Schedule") }
    static var announcement: String { String(localized: "Announcement") }

    static func bracket(_ value: String) -> String {
        "[\(value)]"
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
