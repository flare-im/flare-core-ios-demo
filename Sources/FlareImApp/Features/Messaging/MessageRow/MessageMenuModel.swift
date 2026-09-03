import FlareCoreAppleSDK
import Foundation

enum MessageMenuActionKey: String, CaseIterable, Sendable {
    case reply
    case forward
    case recall
    case resend
    case multiSelect
    case mark
    case pin
    case pinSelf
    case unpin
    case copy
    case preview
    case edit
    case editRich
    case delete
    case save
}

struct MessageMenuActionItem: Identifiable, Equatable, Sendable {
    let key: MessageMenuActionKey
    let title: String
    let symbol: String
    let isDestructive: Bool

    var id: String { key.rawValue }
}

struct MessageMenuModel: Equatable, Sendable {
    let reactions: [String]
    let quickActions: [MessageMenuActionItem]
    let listActions: [MessageMenuActionItem]

    static let quickReactions = ["👽", "👾", "😡", "👍", "❤️", "😂"]
    static let expandedReactions = [
        "👽", "👾", "😡", "👍", "❤️", "😂",
        "😠", "😟", "😳", "😁", "😹", "😢",
        "😮", "🙏", "💙", "💞", "💔", "🤎",
        "😅", "😓", "😇", "🔥", "👏", "✨"
    ]

    static func build(
        message: AppMessage,
        currentUserId: String?,
        isConnected: Bool,
        isPending: Bool,
        isFailed: Bool,
        multiSelectMode: Bool
    ) -> MessageMenuModel {
        // 可用性统一由 MessageActions 判定（真源是核心 domain::message_actions，
        // 由 sdk-spec/message-action-vectors.json 逐位钉住）。
        //
        // 收敛前这里自成一套，与核心有几处分歧，最重的一处是 active 里折了
        // isConnected —— **一断网整个菜单就塌了**（删除/编辑/撤回/置顶全不可用），
        // 而核心只对"重发"要求连接：其余动作是本地或可排队的。
        let can = MessageActions.availability(
            MessageActionInput(
                isSelf: currentUserId.map { message.senderId == $0 } ?? false,
                // ⚠️ 适配要按**这个 app 的真实数据形态**来，不能照抄 wire 字段：
                // core.messageType 常为 0（未填），真正可靠的是 content.contentType；
                // 撤回也不走 status，而是 isRecalled。既有菜单用例正是抓这两点。
                messageType: message.menuNumericType,
                status: message.menuNumericStatus,
                hasText: message.menuCopyableText.isEmpty == false,
                isPending: isPending,
                isPinned: message.menuIsPinned,
                isConnected: isConnected,
                multiSelectMode: multiSelectMode,
                isFailed: isFailed
            )
        )
        let canReact = can.canReact
        let canReply = can.canReply
        let canForward = can.canForward
        let canCopy = can.canCopy
        let canEdit = can.canEdit
        let canDelete = can.canDelete
        let canRecall = can.canRecall
        let canPin = can.canPin
        let canMultiSelect = can.canMultiSelect
        let canSave = can.canSave
        let pinned = message.menuIsPinned

        var quick: [MessageMenuActionItem] = []
        if can.canResend {
            quick.append(item(.resend))
        }
        if canReply {
            quick.append(item(.reply))
        }
        if canForward {
            quick.append(item(.forward))
        }
        if canEdit {
            quick.append(item(.edit))
        }
        if canRecall {
            quick.append(item(.recall))
        }

        var list: [MessageMenuActionItem] = []
        if canMultiSelect {
            list.append(item(.multiSelect))
        }
        if canDelete {
            list.append(item(.mark))
        }
        if can.canPin {
            list.append(item(.pin))
        }
        if can.canUnpin {
            list.append(item(.unpin))
        }
        if canCopy {
            list.append(item(.copy))
        }
        if canMultiSelect {
            list.append(item(.preview))
        }
        if canSave {
            list.append(item(.save))
        }
        if canEdit && !quick.contains(where: { $0.key == .edit }) {
            list.append(item(.edit))
        }
        if canEdit && message.content?.contentType == .richText {
            list.append(item(.editRich))
        }
        if canDelete {
            list.append(item(.delete))
        }

        return MessageMenuModel(
            reactions: canReact ? quickReactions : [],
            quickActions: quick,
            listActions: list
        )
    }

    static func item(_ key: MessageMenuActionKey) -> MessageMenuActionItem {
        switch key {
        case .reply:
            return .init(key: key, title: "回复", symbol: "arrowshape.turn.up.left", isDestructive: false)
        case .forward:
            return .init(key: key, title: "转发", symbol: "arrowshape.turn.up.right", isDestructive: false)
        case .recall:
            return .init(key: key, title: "撤回", symbol: "arrow.uturn.backward", isDestructive: true)
        case .resend:
            return .init(key: key, title: "重新发送", symbol: "arrow.clockwise", isDestructive: false)
        case .multiSelect:
            return .init(key: key, title: "多选", symbol: "list.bullet", isDestructive: false)
        case .mark:
            return .init(key: key, title: "标记", symbol: "flag", isDestructive: false)
        case .pin:
            return .init(key: key, title: "置顶消息", symbol: "pin", isDestructive: false)
        case .pinSelf:
            return .init(key: key, title: "仅自己置顶", symbol: "pin.fill", isDestructive: false)
        case .unpin:
            return .init(key: key, title: "取消置顶", symbol: "pin.slash", isDestructive: false)
        case .copy:
            return .init(key: key, title: "复制", symbol: "doc.on.doc", isDestructive: false)
        case .preview:
            return .init(key: key, title: "预览", symbol: "eye", isDestructive: false)
        case .edit:
            return .init(key: key, title: "编辑文本", symbol: "square.and.pencil", isDestructive: false)
        case .editRich:
            return .init(key: key, title: "编辑富文本", symbol: "doc.richtext", isDestructive: false)
        case .delete:
            return .init(key: key, title: "删除", symbol: "trash", isDestructive: true)
        case .save:
            return .init(key: key, title: "保存到文件", symbol: "square.and.arrow.down", isDestructive: false)
        }
    }
}

private extension AppMessage {
    var menuIsPinned: Bool {
        core.attributes.booleanValue(forAnyOf: ["pinned", "isPinned", "messagePinned"])
    }

    /// 可复制的正文。
    ///
    /// ⚠️ 不能用 previewText：那是**预览**，对图片会回退成 "[图片]" 之类，
    /// 永远非空 —— 用它判断等于"永远可复制"，图片上就会出现点了没用的复制入口。
    var menuCopyableText: String {
        guard let data = core.content?.data else { return "" }
        for key in ["text", "title", "description"] {
            if let value = data[key]?.value as? String,
               value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                return value
            }
        }
        return ""
    }

    /// 映射到核心的数值消息类型。content.contentType 是这个 app 里可靠的来源。
    var menuNumericType: Int {
        switch core.content?.contentType {
        case .text: return 1
        case .image: return 2
        case .video: return 3
        case .audio: return 4
        case .file: return 5
        case .richText: return 15
        case .imageGroup: return 16
        default: return Int(core.messageType)
        }
    }

    /// 映射到核心的数值状态。撤回/删除在这个 app 里走的是布尔字段而非 status。
    var menuNumericStatus: Int {
        if isRecalled { return 5 }
        if menuIsDeleted { return 6 }
        return Int(core.status)
    }

    var menuIsDeleted: Bool {
        core.attributes.booleanValue(forAnyOf: ["deleted", "isDeleted", "messageDeleted"])
    }
}

private extension [String: String] {
    func booleanValue(forAnyOf keys: [String]) -> Bool {
        keys.contains { key in
            guard let value = self[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
                return false
            }
            return value == "true" || value == "1" || value == "yes"
        }
    }
}
