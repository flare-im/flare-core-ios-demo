import FlareCoreAppleSDK
import AVFoundation
import AVKit
import SwiftUI

struct MessageRow: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    let message: AppMessage
    var onOpenMedia: (MediaPreview) -> Void = { _ in }
    var onShowActions: (AppMessage) -> Void = { _ in }

    private var outgoing: Bool {
        guard let current = messaging.currentUserId else { return false }
        return message.senderId == current
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: FlareDesign.Spacing.sm) {
            if outgoing { Spacer(minLength: 70) }
            if !outgoing {
                AvatarView(title: message.senderTitle, imageURL: message.senderAvatar, tint: .blue)
                    .frame(width: 30, height: 30)
            }
            VStack(alignment: outgoing ? .trailing : .leading, spacing: FlareDesign.Spacing.xs) {
                if !outgoing {
                    Text(message.senderTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(FlareDesign.textSecondary)
                        .padding(.leading, FlareDesign.Spacing.xxs)
                }
                messageContent
                if message.isEdited || deliveryState == .failed || deliveryState == .sending {
                    HStack(spacing: FlareDesign.Spacing.xs) {
                        if message.isEdited {
                            Text("Edited")
                        }
                        if outgoing {
                            if deliveryState == .sending {
                                Text("Sending")
                            } else if deliveryState == .failed {
                                Text("Failed")
                            }
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(FlareDesign.textTertiary)
                }
            }
            if !outgoing { Spacer(minLength: 70) }
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.42)
                .onEnded { _ in onShowActions(message) }
        )
        .accessibilityAction(named: Text("More actions")) {
            onShowActions(message)
        }
        .padding(.horizontal, FlareDesign.Spacing.xxs)
    }

    @ViewBuilder
    private var messageContent: some View {
        #if DEBUG
        HStack(alignment: .top, spacing: FlareDesign.Spacing.xs) {
            if outgoing {
                debugMenuButton
            }
            MessageBubble(message: message, outgoing: outgoing, deliveryState: deliveryState, onOpenMedia: onOpenMedia)
            if !outgoing {
                debugMenuButton
            }
        }
        #else
        MessageBubble(message: message, outgoing: outgoing, deliveryState: deliveryState, onOpenMedia: onOpenMedia)
        #endif
    }

    private var debugMenuButton: some View {
        Button {
            onShowActions(message)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(FlareDesign.textSecondary)
                .frame(width: 26, height: 26)
                .background(FlareDesign.surface.opacity(0.94))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Message menu"))
    }

    private var deliveryState: MessageDeliveryState {
        if messaging.pendingMessageKeys.contains(message.appStableId) { return .sending }
        if messaging.failedMessageKeys.contains(message.appStableId) || message.localState?.failed == true { return .failed }
        if message.isRecalled { return .none }
        if outgoing { return message.isRead ? .read : .delivered }
        return .none
    }

}

enum MessageDeliveryState: Equatable {
    case none
    case sending
    case failed
    case delivered
    case read
}

struct MessagePreviewSheet: View {
    let message: AppMessage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.lg) {
                Capsule()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, FlareDesign.Spacing.md)

                HStack(spacing: FlareDesign.Spacing.md) {
                    AvatarView(title: message.senderTitle, imageURL: message.senderAvatar, tint: .blue)
                        .frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.senderTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(FlareDesign.textPrimary)
                        Text(message.content?.contentType.rawValue.replacingOccurrences(of: "_", with: " ") ?? "unknown")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FlareDesign.textSecondary)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
                    Text("消息内容")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(FlareDesign.textSecondary)
                    Text(message.previewText)
                        .font(.body)
                        .foregroundStyle(FlareDesign.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(FlareDesign.Spacing.md)
                        .background(FlareDesign.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
                }

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
                    MessagePreviewMetaRow(title: "消息 ID", value: message.serverId.isEmpty ? message.clientMsgId : message.serverId)
                    MessagePreviewMetaRow(title: "会话", value: message.conversationId)
                    MessagePreviewMetaRow(title: "序号", value: message.seq == 0 ? "-" : String(message.seq))
                }
                .padding(FlareDesign.Spacing.md)
                .background(FlareDesign.surface)
                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.large, style: .continuous))
            }
            .padding(.horizontal, FlareDesign.Spacing.lg)
            .padding(.bottom, FlareDesign.Spacing.xl)
        }
        .background(FlareDesign.appBackground)
    }
}

private struct MessagePreviewMetaRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(FlareDesign.textSecondary)
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(FlareDesign.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MessageActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var messaging: MessagingViewModel
    let message: AppMessage
    var onDismiss: (() -> Void)?
    @State private var reactionPickerExpanded = false
    @State private var pinScopeDialogOpen = false
    private let sheetInset = FlareDesign.Spacing.lg

    private var model: MessageMenuModel {
        MessageMenuModel.build(
            message: message,
            currentUserId: messaging.currentUserId,
            isConnected: messaging.runtimeStatus == .ready,
            isPending: messaging.pendingMessageKeys.contains(message.appStableId) || message.localState?.sending == true,
            isFailed: messaging.failedMessageKeys.contains(message.appStableId) || message.localState?.failed == true,
            multiSelectMode: messaging.isMessageMultiSelectMode
        )
    }

    private var actionGroups: [[MessageMenuActionItem]] {
        let pinnedKeys: Set<MessageMenuActionKey> = [.multiSelect, .mark, .pin, .pinSelf, .unpin]
        let primary = model.listActions.filter { pinnedKeys.contains($0.key) }
        let secondary = model.listActions.filter { !pinnedKeys.contains($0.key) }
        return [primary, secondary].filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FlareDesign.Spacing.sm) {
                Capsule()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 36, height: 4)
                    .padding(.top, FlareDesign.Spacing.md)
                    .padding(.bottom, FlareDesign.Spacing.sm)

                reactionStrip
                if reactionPickerExpanded {
                    expandedReactionPicker
                } else {
                    quickActions
                    actionList
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, FlareDesign.Spacing.lg)
        }
        .background(FlareDesign.surfaceAlt)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
        .animation(.easeOut(duration: 0.18), value: reactionPickerExpanded)
        .confirmationDialog("Choose pin scope", isPresented: $pinScopeDialogOpen, titleVisibility: .visible) {
            Button("Pin for everyone") {
                close()
                Task { await messaging.messageAction("pin", message: message) }
            }
            Button("Pin only for me") {
                close()
                Task { await messaging.messageAction("pinSelf", message: message) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose whether this pinned message is visible to everyone or only your own device.")
        }
    }

    @ViewBuilder
    private var reactionStrip: some View {
        if !model.reactions.isEmpty {
            HStack(spacing: FlareDesign.Spacing.md) {
                ForEach(model.reactions, id: \.self) { reaction in
                    reactionButton(reaction)
                }

                Button {
                    reactionPickerExpanded.toggle()
                } label: {
                    Image(systemName: reactionPickerExpanded ? "chevron.down" : "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(FlareDesign.textSecondary)
                        .frame(width: 42, height: 42)
                        .background(FlareDesign.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.large, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, sheetInset)
            .padding(.vertical, FlareDesign.Spacing.sm)
            .background(FlareDesign.surfaceAlt)
        }
    }

    private var expandedReactionPicker: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.md) {
            HStack {
                Text("选择表情")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(FlareDesign.textPrimary)
                Spacer()
                Button("收起") {
                    reactionPickerExpanded = false
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(FlareDesign.brand)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: FlareDesign.Spacing.sm), count: 6), spacing: FlareDesign.Spacing.sm) {
                ForEach(MessageMenuModel.expandedReactions, id: \.self) { reaction in
                    reactionButton(reaction)
                }
            }
        }
        .padding(FlareDesign.Spacing.md)
        .background(FlareDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.xl, style: .continuous))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, sheetInset)
    }

    private func reactionButton(_ reaction: String) -> some View {
        Button {
            close()
            Task { await messaging.messageAction("react", message: message, reaction: reaction) }
        } label: {
            Text(reaction)
                .font(.system(size: 26))
                .frame(width: 44, height: 44)
                .background(FlareDesign.surface)
                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FlareDesign.Radius.large, style: .continuous)
                        .stroke(Color.black.opacity(0.035), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var quickActions: some View {
        if !model.quickActions.isEmpty {
            HStack(spacing: FlareDesign.Spacing.md) {
                ForEach(model.quickActions) { item in
                    MessageQuickAction(
                        symbol: item.symbol,
                        title: item.title,
                        tint: item.isDestructive ? FlareDesign.danger : FlareDesign.brand
                    ) {
                        dispatch(item.key)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, FlareDesign.Spacing.md)
            .padding(.bottom, FlareDesign.Spacing.xs)
        }
    }

    @ViewBuilder
    private var actionList: some View {
        if !actionGroups.isEmpty {
            VStack(spacing: FlareDesign.Spacing.md) {
                ForEach(Array(actionGroups.enumerated()), id: \.offset) { _, group in
                    VStack(spacing: 0) {
                        ForEach(group) { item in
                            MessageActionRow(
                                symbol: item.symbol,
                                title: item.title,
                                role: item.isDestructive ? .destructive : nil
                            ) {
                                dispatch(item.key)
                            }
                        }
                    }
                    .background(FlareDesign.surface)
                    .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.xl, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: FlareDesign.Radius.xl, style: .continuous)
                            .stroke(Color.black.opacity(0.04), lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, sheetInset)
        }
    }

    private func dispatch(_ key: MessageMenuActionKey) {
        switch key {
        case .reply:
            close()
            messaging.startReply(to: message)
        case .forward:
            runAndClose { await messaging.forwardMessage(message) }
        case .recall:
            runAndClose { await messaging.messageAction("recall", message: message) }
        case .resend:
            runAndClose { await messaging.retry(message) }
        case .multiSelect:
            close()
            messaging.startMultiSelect(with: message)
        case .mark:
            runAndClose { await messaging.messageAction("mark", message: message) }
        case .pin:
            pinScopeDialogOpen = true
        case .pinSelf:
            runAndClose { await messaging.messageAction("pinSelf", message: message) }
        case .unpin:
            runAndClose { await messaging.messageAction("unpin", message: message) }
        case .copy:
            close()
            PlatformClipboard.copy(message.previewText)
            Task { await messaging.noteMessageAction("message.copy", detail: "Copied \(message.appStableId)") }
        case .preview:
            close()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 220_000_000)
                messaging.openMessagePreview(message)
            }
        case .edit:
            runAndClose { await messaging.messageAction("edit", message: message) }
        case .delete:
            runAndClose { await messaging.messageAction("deleteSelf", message: message) }
        case .save:
            runAndClose { await messaging.saveToDownloads(message) }
        }
    }

    private func runAndClose(_ operation: @escaping () async -> Void) {
        close()
        Task { await operation() }
    }

    private func close() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

private struct MessageQuickAction: View {
    let symbol: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FlareDesign.Spacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(height: 26)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(width: 76, height: 60)
            .background(FlareDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FlareDesign.Radius.large, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MessageActionRow: View {
    let symbol: String
    let title: String
    var role: ButtonRole?
    let action: () -> Void

    private var tint: Color {
        role == .destructive ? FlareDesign.danger : FlareDesign.brand
    }

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: FlareDesign.Spacing.lg) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(role == .destructive ? FlareDesign.danger : FlareDesign.textPrimary)
                Spacer()
            }
            .frame(height: 58)
            .padding(.horizontal, FlareDesign.Spacing.lg)
        }
        .buttonStyle(.plain)

        Divider()
            .padding(.leading, 62)
    }
}

// PlatformClipboard now lives in Core/Platform/PlatformClipboard.swift.
