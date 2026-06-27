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
        let recalled = message.isRecalled
        let deleted = message.menuIsDeleted
        let active = isConnected && !recalled && !deleted
        let selfSent = currentUserId.map { message.senderId == $0 } ?? false
        let editableType = message.content?.contentType == .text || message.content?.contentType == .richText
        let pinned = message.menuIsPinned

        let canReact = active && !isPending
        let canReply = !multiSelectMode && !recalled && !deleted
        let canForward = !recalled && !deleted && !isPending
        let canCopy = !recalled && !deleted && message.previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let canEdit = !multiSelectMode && selfSent && active && !isPending && !isFailed && editableType
        let canDelete = active
        let canRecall = !multiSelectMode && selfSent && active && !isFailed
        let canPin = active && !isPending
        let canMultiSelect = !recalled && !deleted
        let mediaType: Bool = {
            switch message.content?.contentType {
            case .image, .imageGroup, .video, .audio, .file: return true
            default: return false
            }
        }()
        let canSave = mediaType && !recalled && !deleted && !isPending

        var quick: [MessageMenuActionItem] = []
        if isFailed && selfSent && isConnected {
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
        if active {
            list.append(item(.mark))
        }
        if canPin {
            list.append(item(pinned ? .unpin : .pin))
        }
        if canCopy {
            list.append(item(.copy))
        }
        if !recalled && !deleted {
            list.append(item(.preview))
        }
        if canSave {
            list.append(item(.save))
        }
        if canEdit && !quick.contains(where: { $0.key == .edit }) {
            list.append(item(.edit))
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
