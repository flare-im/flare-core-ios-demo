import FlareCoreAppleSDK
import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    var onOpenConversation: ((AppConversation) -> Void)?
    @State private var searchText = ""
    @State private var searchActive = false
    @State private var startSheetOpen = false
    @State private var moreSheetOpen = false
    @State private var actionConversation: AppConversation?

    private var filtered: [AppConversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return messaging.visibleConversations }
        return messaging.visibleConversations.filter { conversation in
            [
                conversation.appTitle,
                conversation.conversationId,
                conversation.channelId,
                conversation.appPreview
            ].contains { $0.lowercased().contains(query) }
        }
    }

    private var displayedConversations: [AppConversation] {
        filtered.filter(\.isPinned) + filtered.filter { !$0.isPinned }
    }

    private var availableFilters: [ConversationFilter] {
        [.all, .unread, .mentions]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            filterTabs
            Divider()
            content
        }
        .background(FlareDesign.surface)
        .refreshable {
            await messaging.refreshConversations()
        }
        .onAppear {
            if !availableFilters.contains(environment.filter) {
                environment.filter = .all
            }
        }
        .sheet(isPresented: $startSheetOpen) {
            StartConversationSheet(onConversationOpened: { conversation in
                onOpenConversation?(conversation)
            })
                .presentationDetents([.height(330), .medium])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $moreSheetOpen) {
            MoreActionsSheet(
                onStartConversation: {
                    moreSheetOpen = false
                    startSheetOpen = true
                }
            )
            .presentationDetents([.height(380), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $actionConversation) { conversation in
            ConversationActionSheet(
                conversation: conversation,
                onOpen: {
                    actionConversation = nil
                    open(conversation)
                },
                onAction: { action in
                    runConversationAction(action, for: conversation)
                }
            )
            .presentationDetents([.height(500), .medium])
            .presentationDragIndicator(.hidden)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FlareDesign.Spacing.lg) {
            HStack(alignment: .center, spacing: FlareDesign.Spacing.md) {
                AvatarView(title: currentUserTitle, imageURL: "", tint: .orange)
                    .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                    Text(currentUserTitle)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(FlareDesign.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: FlareDesign.Spacing.xs) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                        Text("Flare IM · \(connectionLabel)")
                            .font(.subheadline)
                            .foregroundStyle(FlareDesign.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                CircleIconButton(symbol: "magnifyingglass", tint: FlareDesign.textSecondary) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        searchActive.toggle()
                    }
                }
                CircleIconButton(symbol: "plus", tint: .white, fill: FlareDesign.brand) {
                    startSheetOpen = true
                }
            }

            if searchActive {
                HStack(spacing: FlareDesign.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(FlareDesign.textTertiary)
                    TextField("Search conversations", text: $searchText)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(FlareDesign.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, FlareDesign.Spacing.md)
                .frame(height: 40)
                .background(FlareDesign.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, FlareDesign.Spacing.lg)
        .padding(.top, FlareDesign.Spacing.lg)
        .padding(.bottom, FlareDesign.Spacing.sm)
        .background(FlareDesign.surface)
    }

    private var filterTabs: some View {
        HStack(spacing: FlareDesign.Spacing.sm) {
            Button {
                moreSheetOpen = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(FlareDesign.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(FlareDesign.surfaceAlt)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More conversation filters")

            HStack(spacing: 0) {
                ForEach(availableFilters) { filter in
                    Button {
                        environment.filter = filter
                        Task { await messaging.refreshConversations() }
                    } label: {
                        Text(filterTitle(for: filter))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(filter == environment.filter ? FlareDesign.brand : FlareDesign.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(
                                Capsule()
                                    .fill(filter == environment.filter ? FlareDesign.surface : Color.clear)
                                    .shadow(color: filter == environment.filter ? Color.black.opacity(0.05) : Color.clear, radius: 8, x: 0, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(FlareDesign.surfaceAlt)
            .clipShape(Capsule())
        }
        .padding(.horizontal, FlareDesign.Spacing.lg)
        .padding(.bottom, FlareDesign.Spacing.md)
        .background(FlareDesign.surface)
    }

    @ViewBuilder
    private var content: some View {
        if filtered.isEmpty {
            EmptyConversationState(
                title: searchText.isEmpty ? String(localized: "No conversations") : String(localized: "No matching conversations"),
                message: searchText.isEmpty ? String(localized: "Tap the plus button to open a conversation") : String(localized: "Try a different keyword"),
                actionTitle: String(localized: "Start a conversation"),
                action: { startSheetOpen = true }
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(displayedConversations) { conversation in
                        ConversationCard(
                            conversation: conversation,
                            onOpen: { open(conversation) },
                            onActions: { actionConversation = conversation }
                        )
                            .contextMenu { conversationMenu(conversation) }
                        Divider()
                            .padding(.leading, 82)
                    }
                }
                .padding(.top, FlareDesign.Spacing.sm)
                .padding(.bottom, 28)
            }
            .background(FlareDesign.surface)
        }
    }

    private var pinnedCount: Int {
        messaging.allConversations.filter(\.isPinned).count
    }

    private var connectionLabel: String {
        switch messaging.runtimeStatus {
        case .ready: return "ready"
        case .loading: return "connecting"
        case .offline: return "offline"
        case .error, .unavailable: return "attention"
        case .idle: return "idle"
        }
    }

    private var currentUserTitle: String {
        let userId = messaging.currentUserId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return userId.isEmpty ? "Flare IM" : userId
    }

    private var statusColor: Color {
        switch messaging.runtimeStatus {
        case .ready: return FlareDesign.success
        case .loading: return FlareDesign.warning
        case .offline, .idle: return FlareDesign.textTertiary
        case .error, .unavailable: return FlareDesign.danger
        }
    }

    private func filterTitle(for filter: ConversationFilter) -> String {
        switch filter {
        case .all:
            return String(localized: "Messages")
        case .unread:
            return String(localized: "Unread")
        case .mentions:
            return filter.title
        case .pinned, .archived, .muted, .drafts:
            return filter.title
        }
    }

    private func open(_ conversation: AppConversation) {
        if let onOpenConversation {
            onOpenConversation(conversation)
        } else {
            Task { await messaging.openConversation(conversation.conversationId) }
        }
    }

    @ViewBuilder
    private func conversationMenu(_ conversation: AppConversation) -> some View {
        Button("Open") {
            open(conversation)
        }
        Button(conversation.isPinned ? "Unpin" : "Pin") {
            runConversationAction("pin", for: conversation)
        }
        Button(conversation.isMuted ? "Unmute" : "Mute") {
            runConversationAction("mute", for: conversation)
        }
        Button(conversation.isArchived ? "Unarchive" : "Archive") {
            runConversationAction("archive", for: conversation)
        }
        Button("Mark as unread") {
            runConversationAction("unread", for: conversation)
        }
        Divider()
        Button("Clear local history", role: .destructive) {
            runConversationAction("clear", for: conversation)
        }
        Button("Delete conversation", role: .destructive) {
            runConversationAction("delete", for: conversation)
        }
    }

    private func runConversationAction(_ action: String, for conversation: AppConversation) {
        Task { await messaging.conversationAction(action, conversation: conversation) }
    }
}

private struct CircleIconButton: View {
    let symbol: String
    var tint: Color
    var fill: Color = FlareDesign.surfaceAlt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(fill)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol)
    }
}

private struct ConversationCard: View {
    let conversation: AppConversation
    var onOpen: () -> Void
    var onActions: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
                    AvatarView(title: conversation.appTitle, imageURL: conversation.avatarUrl, tint: avatarColor)
                        .frame(width: 50, height: 50)
                        .overlay(alignment: .bottomTrailing) {
                            if conversation.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(FlareDesign.brand)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(FlareDesign.surface, lineWidth: 2))
                                    .offset(x: 2, y: 2)
                            }
                        }

                    VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                        HStack(alignment: .firstTextBaseline, spacing: FlareDesign.Spacing.sm) {
                            Text(conversation.appTitle)
                                .font(.system(size: 20, weight: conversation.unreadCount > 0 ? .bold : .semibold))
                                .foregroundStyle(FlareDesign.textPrimary)
                                .lineLimit(1)

                            tagStrip
                        }
                        previewLine
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: FlareDesign.Spacing.sm) {
                        Text(displayDate)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(FlareDesign.textSecondary)
                        if conversation.unreadCount > 0 {
                            Text("\(conversation.unreadCount)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 24, minHeight: 24)
                                    .background(FlareDesign.brand)
                                    .clipShape(Circle())
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onActions) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(FlareDesign.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(FlareDesign.surfaceAlt)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black.opacity(0.04), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Conversation actions")
        }
        .padding(.horizontal, FlareDesign.Spacing.lg)
        .padding(.vertical, FlareDesign.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 78)
        .background(rowBackground)
        .overlay(alignment: .leading) {
            if conversation.isPinned {
                Rectangle()
                    .fill(FlareDesign.brand.opacity(0.55))
                    .frame(width: 3)
            }
        }
    }

    private var previewText: String {
        conversation.appPreview.isEmpty ? String(localized: "No messages") : conversation.appPreview
    }

    @ViewBuilder
    private var previewLine: some View {
        HStack(spacing: FlareDesign.Spacing.xs) {
            if isDraft {
                Text("Draft")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FlareDesign.danger)
            }

            if let key = EmojiPresentation.lonePackKey(in: previewText) {
                FlareAssetImageView(
                    url: EmojiPresentation.emojiURL(for: key),
                    fallbackSystemImage: "face.smiling",
                    accessibilityLabel: key,
                    size: 22,
                    travel: 0,
                    rotation: 0,
                    isAnimated: false
                )
                    .frame(width: 30, height: 24, alignment: .leading)
            } else {
                Text(previewBody)
                    .font(.subheadline)
                    .foregroundStyle(isDraft ? FlareDesign.textPrimary : FlareDesign.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var tagStrip: some View {
        HStack(spacing: FlareDesign.Spacing.xs) {
            if conversation.conversationType == .group {
                ConversationTag(text: "Group", tone: .info)
            }
            if let roleTag {
                ConversationTag(text: roleTag, tone: .warning)
            }
            if conversation.mentionMe || conversation.mentionCount > 0 {
                ConversationTag(text: "@", tone: .warning)
            }
            if conversation.isMuted {
                Image(systemName: "bell.slash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlareDesign.textTertiary)
            }
        }
    }

    private var isDraft: Bool {
        conversation.draft?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var previewBody: String {
        guard isDraft else { return previewText }
        return previewText.replacingOccurrences(of: "Draft: ", with: "")
    }

    private var roleTag: String? {
        guard let role = conversation.role?.trimmingCharacters(in: .whitespacesAndNewlines), !role.isEmpty else {
            return nil
        }
        let lower = role.lowercased()
        if lower.contains("bot") || lower.contains("robot") {
            return "Bot"
        }
        if lower.contains("official") {
            return "Official"
        }
        return role.prefix(10).description
    }

    private var displayDate: String {
        guard let date = FlareFormatters.dateFromMillis(conversation.appSortTimestamp) else { return "" }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "M/d"
        } else {
            formatter.dateFormat = "yyyy/M/d"
        }
        return formatter.string(from: date)
    }

    private var avatarColor: Color {
        let colors: [Color] = [.green, .orange, .blue, .purple, .indigo, .teal]
        let index = abs(conversation.appTitle.hashValue) % colors.count
        return colors[index]
    }

    private var rowBackground: Color {
        conversation.isPinned ? FlareDesign.brandSoft.opacity(0.16) : FlareDesign.surface
    }
}

private struct ConversationTag: View {
    let text: String
    var tone: RuntimeTone

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(FlareDesign.color(for: tone))
            .lineLimit(1)
            .padding(.horizontal, FlareDesign.Spacing.xs)
            .frame(height: 18)
            .background(FlareDesign.color(for: tone).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.small, style: .continuous))
    }
}

private struct ConversationActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let conversation: AppConversation
    let onOpen: () -> Void
    let onAction: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: FlareDesign.Spacing.md) {
                Capsule()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 36, height: 4)
                    .padding(.top, FlareDesign.Spacing.md)

                header
                quickActions
                managementGroup
                dangerGroup
            }
            .padding(.horizontal, FlareDesign.Spacing.lg)
            .padding(.bottom, FlareDesign.Spacing.xl)
        }
        .background(FlareDesign.surfaceAlt)
    }

    private var header: some View {
        HStack(spacing: FlareDesign.Spacing.md) {
            AvatarView(title: conversation.appTitle, imageURL: conversation.avatarUrl, tint: .orange)
                .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                HStack(spacing: FlareDesign.Spacing.sm) {
                    Text(conversation.appTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(FlareDesign.textPrimary)
                        .lineLimit(1)
                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(FlareDesign.brand)
                    }
                    if conversation.isMuted {
                        Image(systemName: "bell.slash")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(FlareDesign.textTertiary)
                    }
                }
                Text(conversation.appPreview.isEmpty ? String(localized: "No messages") : conversation.appPreview)
                    .font(.footnote)
                    .foregroundStyle(FlareDesign.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(FlareDesign.Spacing.md)
        .background(FlareDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FlareDesign.Radius.xl, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private var quickActions: some View {
        HStack(spacing: FlareDesign.Spacing.sm) {
            ConversationQuickAction(symbol: "arrow.right", title: "Open", tint: FlareDesign.brand) {
                dismiss()
                onOpen()
            }
            ConversationQuickAction(
                symbol: conversation.isPinned ? "pin.slash" : "pin",
                title: conversation.isPinned ? "Unpin" : "Pin",
                tint: FlareDesign.brand
            ) {
                run("pin")
            }
            ConversationQuickAction(
                symbol: conversation.isMuted ? "bell" : "bell.slash",
                title: conversation.isMuted ? "Unmute" : "Mute",
                tint: FlareDesign.textSecondary
            ) {
                run("mute")
            }
            ConversationQuickAction(symbol: "mail.badge", title: "Unread", tint: FlareDesign.brand) {
                run("unread")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var managementGroup: some View {
        VStack(spacing: 0) {
            ConversationActionRow(
                symbol: conversation.isArchived ? "archivebox" : "archivebox.fill",
                title: conversation.isArchived ? "Unarchive" : "Archive",
                tint: FlareDesign.textSecondary
            ) {
                run("archive")
            }
        }
        .background(FlareDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FlareDesign.Radius.xl, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private var dangerGroup: some View {
        VStack(spacing: 0) {
            ConversationActionRow(symbol: "eraser", title: "Clear local history", tint: FlareDesign.danger, isDestructive: true) {
                run("clear")
            }
            Divider()
                .padding(.leading, 58)
            ConversationActionRow(symbol: "trash", title: "Delete conversation", tint: FlareDesign.danger, isDestructive: true) {
                run("delete")
            }
        }
        .background(FlareDesign.surface)
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FlareDesign.Radius.xl, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    private func run(_ action: String) {
        dismiss()
        onAction(action)
    }
}

private struct ConversationQuickAction: View {
    let symbol: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: FlareDesign.Spacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(height: 22)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
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

private struct ConversationActionRow: View {
    let symbol: String
    let title: String
    let tint: Color
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FlareDesign.Spacing.md) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDestructive ? FlareDesign.danger : FlareDesign.textPrimary)
                Spacer(minLength: 0)
            }
            .frame(height: 58)
            .padding(.horizontal, FlareDesign.Spacing.lg)
        }
        .buttonStyle(.plain)
    }
}

struct AvatarView: View {
    let title: String
    let imageURL: String
    var tint: Color = FlareDesign.brand

    var body: some View {
        ZStack {
            Circle()
                .fill(tint)
            Text(initials)
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(title)
    }

    private var initials: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.first {
            return String(first).uppercased()
        }
        return "#"
    }
}

private struct EmptyConversationState: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: FlareDesign.Spacing.md) {
            Spacer(minLength: 92)
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(FlareDesign.textTertiary)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(FlareDesign.textPrimary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(FlareDesign.textTertiary)
            Button(actionTitle, action: action)
                .font(.footnote.weight(.bold))
                .buttonStyle(.borderedProminent)
                .tint(FlareDesign.brand)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FlareDesign.surface)
    }
}

private struct StartConversationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var messaging: MessagingViewModel
    var onConversationOpened: ((AppConversation) -> Void)?
    @State private var kind: StartConversationKind = .single
    @State private var peerUserId = ""
    @State private var groupUserIds = ""
    @State private var isOpening = false
    @State private var localError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Open conversation")
                    .font(.headline.weight(.bold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)
            .padding(.top, FlareDesign.Spacing.xl)
            .padding(.bottom, FlareDesign.Spacing.xl)

            VStack(alignment: .leading, spacing: FlareDesign.Spacing.lg) {
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
                    Text(kind == .single ? "Peer ID" : "Member IDs")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FlareDesign.brand)
                    if kind == .single {
                        TextField("Enter the peer's real userId", text: $peerUserId)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        TextField("Enter member userIds separated by commas", text: $groupUserIds)
                            .textFieldStyle(.roundedBorder)
                    }
                    Text(kind == .single ? "The conversation ID is generated automatically by the SDK via getOneConversation" : "The group conversation is generated automatically by the SDK via getGroupConversationByUserIds")
                        .font(.caption)
                        .foregroundStyle(FlareDesign.textTertiary)
                }

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
                    Text("Conversation type")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(FlareDesign.brand)
                    Picker("Conversation type", selection: $kind) {
                        ForEach(StartConversationKind.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)

            if let validationMessage {
                InlineSheetBanner(
                    symbol: "info.circle.fill",
                    title: String(localized: "Needs adjustment"),
                    message: validationMessage,
                    tone: .warning
                )
                .padding(.horizontal, FlareDesign.Spacing.xl)
                .padding(.top, FlareDesign.Spacing.md)
            } else if let localError {
                InlineSheetBanner(
                    symbol: "exclamationmark.triangle.fill",
                    title: String(localized: "Couldn't open conversation"),
                    message: localError,
                    tone: .danger
                )
                .padding(.horizontal, FlareDesign.Spacing.xl)
                .padding(.top, FlareDesign.Spacing.md)
            }

            Spacer(minLength: 16)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(FlareDesign.textSecondary)
                Button("Open") {
                    openConversation()
                }
                .font(.subheadline.weight(.bold))
                .buttonStyle(.borderedProminent)
                .tint(FlareDesign.brand)
                .disabled(!canOpen)
                .overlay {
                    if isOpening {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    }
                }
                .opacity(isOpening ? 0.72 : 1)
                Spacer()
            }
            .padding(FlareDesign.Spacing.xl)
            .background(FlareDesign.surfaceAlt.opacity(0.55))
        }
        .background(FlareDesign.surface)
        .onAppear {
            peerUserId = messaging.startConversationDraft.peerUserId
            groupUserIds = messaging.startConversationDraft.groupUserIds
        }
    }

    private var trimmedPeer: String {
        peerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var groupIds: [String] {
        groupUserIds
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var validationMessage: String? {
        switch kind {
        case .single:
            guard !trimmedPeer.isEmpty else { return nil }
            if trimmedPeer == messaging.currentUserId {
                return String(localized: "You can't start a direct chat with your own account; enter the peer's real userId.")
            }
            return nil
        case .group:
            if groupIds.contains(where: { $0 == messaging.currentUserId }) {
                return String(localized: "Only enter the other members' IDs; your own account is resolved from the server context.")
            }
            return nil
        }
    }

    private var canOpen: Bool {
        guard !isOpening, validationMessage == nil else { return false }
        switch kind {
        case .single:
            return !trimmedPeer.isEmpty
        case .group:
            return !groupIds.isEmpty
        }
    }

    private func openConversation() {
        localError = nil
        isOpening = true
        messaging.startConversationDraft.peerUserId = trimmedPeer
        messaging.startConversationDraft.groupUserIds = groupIds.joined(separator: ",")
        Task {
            let conversation: AppConversation?
            switch kind {
            case .single:
                conversation = await messaging.openPeerConversation()
            case .group:
                conversation = await messaging.openGroupConversation()
            }
            isOpening = false
            if let conversation {
                onConversationOpened?(conversation)
                dismiss()
            } else {
                localError = environment.lastError ?? String(localized: "Make sure the peer account exists, the local service is running, and the current protocol address is reachable.")
            }
        }
    }
}

private struct InlineSheetBanner: View {
    let symbol: String
    let title: String
    let message: String
    let tone: RuntimeTone

    var body: some View {
        HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 20, height: 20)
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                Text(title)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(FlareDesign.textPrimary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(FlareDesign.textSecondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(FlareDesign.Spacing.md)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
    }

    private var iconColor: Color {
        switch tone {
        case .danger: return FlareDesign.danger
        case .warning: return FlareDesign.warning
        case .success: return FlareDesign.success
        default: return FlareDesign.brand
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .danger: return FlareDesign.danger.opacity(0.10)
        case .warning: return FlareDesign.warning.opacity(0.12)
        case .success: return FlareDesign.success.opacity(0.12)
        default: return FlareDesign.brandSoft
        }
    }
}

private struct MoreActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    let onStartConversation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("More")
                .font(.headline.weight(.bold))
                .padding(.horizontal, FlareDesign.Spacing.xl)
                .padding(.top, FlareDesign.Spacing.xl)
                .padding(.bottom, FlareDesign.Spacing.lg)

            HStack(spacing: FlareDesign.Spacing.md) {
                AvatarView(title: messaging.currentUserId ?? "F", imageURL: "", tint: FlareDesign.brand)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: FlareDesign.Spacing.xxs) {
                    Text("Current account")
                        .font(.caption)
                        .foregroundStyle(FlareDesign.textTertiary)
                    Text(messaging.currentUserId ?? "-")
                        .font(.headline.weight(.bold))
                }
                Spacer()
                StatusPill(text: connectionLabel, tone: messaging.runtimeStatus.productTone)
            }
            .padding(FlareDesign.Spacing.lg)
            .background(FlareDesign.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: FlareDesign.radius, style: .continuous))
            .padding(.horizontal, FlareDesign.Spacing.lg)
            .padding(.bottom, FlareDesign.Spacing.md)

            ActionRow(symbol: "plus", title: String(localized: "New conversation"), tint: FlareDesign.brand, action: onStartConversation)
            ActionRow(symbol: "arrow.triangle.2.circlepath", title: String(localized: "Fetch from server"), tint: FlareDesign.brand) {
                dismiss()
                Task { await messaging.refreshConversations() }
            }
            Divider().padding(.horizontal, FlareDesign.Spacing.lg).padding(.vertical, FlareDesign.Spacing.sm)
            ActionRow(symbol: "info.circle", title: String(localized: "SDK Status"), tint: FlareDesign.brand) {
                environment.section = .sdkLab
                dismiss()
            }
            ActionRow(symbol: "gearshape", title: String(localized: "Settings"), tint: FlareDesign.brand) {
                environment.section = .settings
                dismiss()
            }
            ActionRow(symbol: "rectangle.portrait.and.arrow.right", title: String(localized: "Logout"), tint: FlareDesign.danger) {
                dismiss()
                Task { await messaging.logout() }
            }
            Spacer()
        }
        .background(FlareDesign.surface)
    }

    private var connectionLabel: String {
        messaging.runtimeStatus == .ready ? "Ready" : messaging.runtimeStatus.productLabel
    }
}

private struct ActionRow: View {
    let symbol: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FlareDesign.Spacing.lg) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint == FlareDesign.danger ? FlareDesign.danger : FlareDesign.textPrimary)
                Spacer()
            }
            .padding(.horizontal, FlareDesign.Spacing.xl)
            .padding(.vertical, FlareDesign.Spacing.md)
        }
        .buttonStyle(.plain)
    }
}

struct ConversationDetailsPanel: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    let conversation: AppConversation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xl) {
                HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
                    AvatarView(title: conversation.appTitle, imageURL: conversation.avatarUrl)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: FlareDesign.Spacing.xs) {
                        Text(conversation.appTitle)
                            .font(.title3.weight(.bold))
                        Text(conversation.conversationId)
                            .font(.caption.monospaced())
                            .foregroundStyle(FlareDesign.textSecondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button {
                        environment.detailsOpen = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }

                StatusBanner(status: messaging.runtimeStatus, error: messaging.lastError)
                actionGrid

                KeyValueRows(values: [
                    ("Type", conversation.conversationType.rawValue),
                    ("Channel", conversation.channelId),
                    ("Members", "\(conversation.membersCount)"),
                    ("Unread", "\(conversation.unreadCount)"),
                    ("Mention count", "\(conversation.mentionCount)"),
                    ("Pinned", String(conversation.isPinned)),
                    ("Muted", String(conversation.isMuted)),
                    ("Archived", String(conversation.isArchived)),
                    ("Draft", conversation.draft ?? ""),
                    ("Role", conversation.role ?? ""),
                    ("Version", "\(conversation.version)"),
                    ("Last read seq", "\(conversation.lastReadSeq)"),
                    ("Max seq", "\(conversation.maxSeq)")
                ])
                .padding(FlareDesign.Spacing.md)
                .flarePanel()
            }
            .padding(FlareDesign.Spacing.lg)
        }
        .background(FlareDesign.appBackground)
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: FlareDesign.Spacing.sm)], spacing: FlareDesign.Spacing.sm) {
            Button(conversation.isPinned ? "Unpin" : "Pin") {
                Task { await messaging.conversationAction("pin", conversation: conversation) }
            }
            Button(conversation.isMuted ? "Unmute" : "Mute") {
                Task { await messaging.conversationAction("mute", conversation: conversation) }
            }
            Button(conversation.isArchived ? "Unarchive" : "Archive") {
                Task { await messaging.conversationAction("archive", conversation: conversation) }
            }
            Button("Sync") {
                Task { await messaging.syncSelectedConversation() }
            }
            Button("Mark unread") {
                Task { await messaging.conversationAction("unread", conversation: conversation) }
            }
            Button("Clear local", role: .destructive) {
                Task { await messaging.conversationAction("clear", conversation: conversation) }
            }
        }
        .buttonStyle(.bordered)
    }
}
