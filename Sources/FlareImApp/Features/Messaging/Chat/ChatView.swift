import FlareCoreAppleSDK
import AVFoundation
import AVKit
import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var search: SearchViewModel
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    let conversation: AppConversation
    var showsBackButton = false
    var onBack: () -> Void = {}
    @State private var composerText = ""
    @State private var searchSheetOpen = false
    @State private var detailsSheetOpen = false
    @State private var actionMessage: AppMessage?
    @State private var mediaPreview: MediaPreview?
    @State private var loadOlderAnchorId: String?
    @State private var loadingOlderMessages = false
    @State private var timelineFollowsTail = true

    private static let timelineBottomAnchorId = "flare.timeline.bottom"
    private static let timelineTimeGapSeconds: TimeInterval = 5 * 60

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header
                    Divider()
                    timeline
                        .frame(maxHeight: .infinity)
                    ComposerView(
                        text: $composerText,
                        conversation: conversation,
                        expandedInputHeight: expandedComposerInputHeight(for: geometry.size.height)
                    )
                }

                if let actionMessage {
                    messageActionOverlay(message: actionMessage, availableHeight: geometry.size.height)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(FlareDesign.appBackground)
        .animation(.easeOut(duration: 0.2), value: actionMessage?.appStableId)
        .sheet(isPresented: $searchSheetOpen) {
            ChatSearchSheet(viewModel: search, conversation: conversation)
                .presentationDetents([.height(550), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $detailsSheetOpen) {
            ConversationDetailsPanel(conversation: conversation)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $mediaPreview) { preview in
            MediaPreviewSheet(preview: preview)
        }
        .sheet(item: $messaging.previewTarget) { message in
            MessagePreviewSheet(message: message)
                .presentationDetents([.height(420), .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            await messaging.openConversation(conversation.conversationId)
        }
        .onChange(of: conversation.conversationId) { _ in
            timelineFollowsTail = true
        }
    }

    private func messageActionOverlay(message: AppMessage, availableHeight: CGFloat) -> some View {
        let sheetHeight = min(560, max(430, availableHeight * 0.68))
        return ZStack(alignment: .bottom) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture {
                    actionMessage = nil
                }

            MessageActionSheet(message: message, onDismiss: {
                actionMessage = nil
            })
            .frame(maxWidth: .infinity)
            .frame(height: sheetHeight)
            .background(FlareDesign.surfaceAlt)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 28,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 28,
                    style: .continuous
                )
            )
            .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: -8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
    }

    private func expandedComposerInputHeight(for availableHeight: CGFloat) -> CGFloat {
        let reservedChromeHeight: CGFloat = 166
        return max(240, availableHeight - reservedChromeHeight)
    }

    private var timelineTailSignature: String {
        "\(messaging.selectedMessages.count):\(messaging.selectedMessages.last?.appStableId ?? "")"
    }

    private var latestMessageIsFromCurrentUser: Bool {
        guard let currentUserId = messaging.currentUserId,
              let latest = messaging.selectedMessages.last else { return false }
        return latest.senderId == currentUserId
    }

    private var header: some View {
        HStack(spacing: FlareDesign.Spacing.md) {
            if showsBackButton {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            AvatarView(title: conversation.appTitle, imageURL: conversation.avatarUrl, tint: .orange)
                .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.xxs) {
                Text(conversation.appTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(FlareDesign.textPrimary)
                    .lineLimit(1)
                HStack(spacing: FlareDesign.Spacing.xs) {
                    Circle()
                        .fill(messaging.runtimeStatus == .ready ? FlareDesign.success : FlareDesign.warning)
                        .frame(width: 5, height: 5)
                    Text(messaging.runtimeStatus == .ready ? String(localized: "Online") : messaging.runtimeStatus.productLabel)
                        .font(.caption)
                        .foregroundStyle(FlareDesign.textSecondary)
                }
            }
            Spacer(minLength: 8)
            HeaderIconButton(symbol: "phone") {}
                .disabled(true)
                .opacity(0.65)
            HeaderIconButton(symbol: "video") {}
                .disabled(true)
                .opacity(0.65)
            HeaderIconButton(symbol: "magnifyingglass") {
                search.draft.conversationScoped = true
                search.draft.keyword = ""
                searchSheetOpen = true
            }
            HeaderIconButton(symbol: "chart.bar.xaxis") {
                environment.detailsOpen.toggle()
            }
            HeaderIconButton(symbol: "ellipsis") {
                detailsSheetOpen = true
            }
        }
        .padding(.horizontal, FlareDesign.Spacing.md)
        .padding(.vertical, FlareDesign.Spacing.sm)
        .background(FlareDesign.surface)
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: FlareDesign.Spacing.md) {
                    if messaging.selectedConversationHasMoreMessages {
                        Button {
                            Task { await loadOlderMessages(preserving: proxy) }
                        } label: {
                            Label(
                                loadingOlderMessages ? String(localized: "Loading...") : String(localized: "Load earlier messages"),
                                systemImage: "clock.arrow.circlepath"
                            )
                            .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(loadingOlderMessages)
                        .padding(.top, FlareDesign.Spacing.md)
                    } else if !messaging.selectedMessages.isEmpty {
                        Text("No earlier messages")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(FlareDesign.textTertiary)
                            .padding(.horizontal, FlareDesign.Spacing.md)
                            .padding(.vertical, FlareDesign.Spacing.xs)
                            .background(FlareDesign.surface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
                            .padding(.top, FlareDesign.Spacing.md)
                    }

                    if messaging.selectedMessages.isEmpty {
                        EmptyStateView(
                            title: String(localized: "No messages"),
                            message: String(localized: "Send the first message, or use the tools below to build media, tasks, polls, and more."),
                            symbol: "bubble.left.and.bubble.right"
                        )
                        .frame(minHeight: 420)
                    } else {
                        ForEach(Array(messaging.selectedMessages.enumerated()), id: \.element.appStableId) { index, message in
                            if shouldShowDate(at: index) {
                                TimelineDatePill(text: timelineDateText(for: message))
                            }
                            MessageRow(message: message, onOpenMedia: { preview in
                                mediaPreview = preview
                            }) { selected in
                                actionMessage = selected
                            }
                                .id(message.appStableId)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(Self.timelineBottomAnchorId)
                        .onAppear {
                            timelineFollowsTail = true
                        }
                }
                .padding(.horizontal, FlareDesign.Spacing.sm)
                .padding(.bottom, FlareDesign.Spacing.lg)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        if value.translation.height > 16 {
                            timelineFollowsTail = false
                        }
                    }
            )
            .onChange(of: timelineTailSignature) { _ in
                if let anchor = loadOlderAnchorId {
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(anchor, anchor: .top)
                    }
                } else if timelineFollowsTail || latestMessageIsFromCurrentUser {
                    timelineFollowsTail = true
                    scrollToTimelineBottom(proxy)
                }
            }
            .onAppear {
                timelineFollowsTail = true
                scrollToTimelineBottomSoon(proxy)
            }
            .onChange(of: conversation.conversationId) { _ in
                timelineFollowsTail = true
                scrollToTimelineBottomSoon(proxy)
            }
        }
        .refreshable {
            await messaging.openConversation(conversation.conversationId)
        }
    }

    private func scrollToTimelineBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.22)) {
            proxy.scrollTo(Self.timelineBottomAnchorId, anchor: .bottom)
        }
    }

    private func scrollToTimelineBottomSoon(_ proxy: ScrollViewProxy) {
        let delays: [TimeInterval] = [0, 0.16, 0.42]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard timelineFollowsTail, loadOlderAnchorId == nil else { return }
                scrollToTimelineBottom(proxy)
            }
        }
    }

    private func loadOlderMessages(preserving proxy: ScrollViewProxy) async {
        guard !loadingOlderMessages else { return }
        loadingOlderMessages = true
        timelineFollowsTail = false
        let anchor = messaging.selectedMessages.first?.appStableId
        loadOlderAnchorId = anchor
        await messaging.loadOlderMessages()
        if let anchor {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(anchor, anchor: .top)
            }
        }
        loadOlderAnchorId = nil
        loadingOlderMessages = false
    }

    private func shouldShowDate(at index: Int) -> Bool {
        guard index >= 0, index < messaging.selectedMessages.count else { return false }
        if index == 0 { return true }
        let current = FlareFormatters.dateFromMillis(messaging.selectedMessages[index].appSortTimestamp)
        let previous = FlareFormatters.dateFromMillis(messaging.selectedMessages[index - 1].appSortTimestamp)
        guard let current, let previous else { return false }
        if !Calendar.current.isDate(current, inSameDayAs: previous) { return true }
        return current.timeIntervalSince(previous) >= Self.timelineTimeGapSeconds
    }

    private func timelineDateText(for message: AppMessage) -> String {
        guard let date = FlareFormatters.dateFromMillis(message.appSortTimestamp) else { return "" }
        if Calendar.current.isDateInToday(date) { return FlareFormatters.shortTime.string(from: date) }
        if Calendar.current.isDateInYesterday(date) {
            return String(localized: "Yesterday \(FlareFormatters.shortTime.string(from: date))")
        }
        return FlareFormatters.shortDateTime.string(from: date)
    }
}

private struct HeaderIconButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(FlareDesign.Typography.headline)
                .foregroundStyle(FlareDesign.textSecondary)
                .frame(width: 31, height: 31)
        }
        .buttonStyle(.plain)
    }
}

private struct TimelineDatePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(FlareDesign.textTertiary)
            .padding(.horizontal, FlareDesign.Spacing.md)
            .padding(.vertical, FlareDesign.Spacing.xs)
            .background(FlareDesign.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
            .padding(.vertical, FlareDesign.Spacing.xs)
    }
}
