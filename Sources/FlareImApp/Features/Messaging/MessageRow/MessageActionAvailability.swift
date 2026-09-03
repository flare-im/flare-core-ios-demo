import Foundation

/// 与核心 `domain::message_actions` 的 `MessageActionContext` 一一对应。
struct MessageActionInput: Sendable {
    var isSelf: Bool
    var messageType: Int
    var status: Int
    var hasText: Bool
    var isPending: Bool
    var isPinned: Bool
    var isConnected: Bool
    var multiSelectMode: Bool
    var isFailed: Bool
}

struct MessageActionAvailability: Sendable, Equatable {
    var canReply = false
    var canForward = false
    var canCopy = false
    var canEdit = false
    var canDelete = false
    var canRecall = false
    var canPin = false
    var canUnpin = false
    var canReact = false
    var canMultiSelect = false
    var canSave = false
    var canResend = false
}

/// 一条消息此刻可用的动作。
///
/// **真源是核心 `domain::message_actions`**；这里是它在 iOS 侧的实现，由
/// `sdk-spec/message-action-vectors.json` 逐位钉住（见 MessageActionVectorsTests）。
///
/// 收敛前 iOS 与核心有几处分歧，最重的一处是 `active` 里折了 `isConnected` ——
/// **一断网整个菜单就塌了**（删除 / 编辑 / 撤回 / 置顶全不可用），
/// 而核心只对"重发"要求连接：其余动作是本地或可排队的。
enum MessageActions {
    private static let statusFailed = 4
    private static let statusRecalled = 5
    private static let statusDeleted = 6
    private static let typeText = 1
    private static let typeRichText = 15
    private static let mediaTypes: Set<Int> = [2, 3, 4, 5, 16]

    static func availability(_ input: MessageActionInput) -> MessageActionAvailability {
        let recalled = input.status == statusRecalled
        let deleted = input.status == statusDeleted
        let active = !recalled && !deleted

        let isFailed = input.isFailed || input.status == statusFailed
        let selfSent = input.isSelf
        let editableType = input.messageType == typeText || input.messageType == typeRichText
        let mediaType = mediaTypes.contains(input.messageType)
        let single = !input.multiSelectMode

        return MessageActionAvailability(
            canReply: single && active,
            canForward: active && !input.isPending,
            // 复制看的是"有没有可复制的正文"，而不是消息类型。
            canCopy: active && input.hasText,
            canEdit: single && selfSent && active && !input.isPending && !isFailed && editableType,
            canDelete: active,
            canRecall: single && selfSent && active && !isFailed,
            canPin: active && !input.isPending && !input.isPinned,
            canUnpin: active && !input.isPending && input.isPinned,
            canReact: active && !input.isPending,
            canMultiSelect: active,
            canSave: mediaType && active && !input.isPending,
            canResend: isFailed && selfSent && input.isConnected
        )
    }
}
